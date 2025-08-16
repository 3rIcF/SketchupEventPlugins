# frozen_string_literal: true

# Elementaro AutoInfo v2.3.0 — performance & UX
# - Iterativer Scan (kein Rekursionslimit)
# - Scan-/Filter-Cache
# - Katalog-Ansicht (alle Definitionen)
# - Thumbs: Queue + Cache
# - UI aus separaten Dateien (ui/index.html, app.js, styles.css)

require 'sketchup.rb'
require 'json'
require 'csv'
require 'fileutils'

module ElementaroInfo
  extend self

      VERSION         = '2.3.0'.freeze
      DEFAULT_KEYS    = %w[sku variant unit price_eur owner supplier article_number description].freeze
      DEFAULT_DEC     = 2
      MAX_DEPTH_HARD  = 50
      CHUNK_SIZE      = 3000
      THUMB_DIR       = File.join(Sketchup.temp_dir, 'elementaro_thumbs').freeze

      @dlg          = nil
      @cache_rows   = nil        # Ergebnis des letzten Scans (Detailzeilen)
      @cache_opts   = nil        # Optionen des letzten Scans
      @defs_summary = nil        # Aggregierte Definitionsliste (für Katalog)
      @model_dirty  = true
      @tag_vis_stack = []
      @cancel_scan  = false

      # -------- Observers: markiere Änderungen ----------
      class ModelObs < Sketchup::ModelObserver
        def onTransactionCommit(model); ElementaroInfo.mark_dirty!; end
        def onEraseEntities(model);     ElementaroInfo.mark_dirty!; end
      end
      class SelObs < Sketchup::SelectionObserver
        def onSelectionBulkChange(s); ElementaroInfo.push_selection; end
        def onSelectionCleared(s);    ElementaroInfo.push_selection; end
        def onSelectedAdded(s, _);    ElementaroInfo.push_selection; end
        def onSelectedRemoved(s, _);  ElementaroInfo.push_selection; end
      end

      def mark_dirty!; @model_dirty = true; end

      def attach_observers
        m = Sketchup.active_model
        (@model_obs ||= ModelObs.new)
        (@sel_obs   ||= SelObs.new)
        m.add_observer(@model_obs) rescue nil
        m.selection.add_observer(@sel_obs) rescue nil
      end

      # ---------------- Entry ----------------
      def show_panel
        @dlg&.close
        FileUtils.mkdir_p(THUMB_DIR) unless File.directory?(THUMB_DIR)
        attach_observers

        @dlg = UI::HtmlDialog.new(
          dialog_title: "Elementaro AutoInfo v#{VERSION}",
          preferences_key: 'elementaro.autoinfo',
          scrollable: true, resizable: true, width: 1240, height: 860
        )
        wire_callbacks

        # UI aus Datei laden
        ui_root = File.join(__dir__, 'ui')
        index   = File.join(ui_root, 'index.html')
        if File.exist?(index)
          @dlg.set_file(index)
        else
          @dlg.set_html("<html><body><pre>UI-Datei fehlt: #{index}</pre></body></html>")
        end
        @dlg.show
      end

      # ---------------- Callbacks ----------------
      def wire_callbacks
        @dlg.add_action_callback('web_ready') do |_c, _|
          push_selection
          send_rows(scan_with_cache(default_opts))
          send_defs_summary # Katalog füttern
        end

        @dlg.add_action_callback('requestData') do |_c, payload|
          opts = default_opts.merge((JSON.parse(payload.to_s) rescue {}))
          send_rows(scan_with_cache(opts))
          send_defs_summary
        end

        @dlg.add_action_callback('exportCsv'){ |_c, rows| export_rows(rows, :csv) }
        @dlg.add_action_callback('exportJson'){ |_c, rows| export_rows(rows, :json) }
        @dlg.add_action_callback('exportZip'){ |_c, rows| export_rows(rows, :zip) }

        # Thumbnails
        @dlg.add_action_callback('thumbsMissing'){ |_c, defs| queue_thumbs(parse_defs(defs), only_missing: true) }
        @dlg.add_action_callback('thumbsAll'){ |_c, defs| queue_thumbs(parse_defs(defs), only_missing: false) }
        @dlg.add_action_callback('clearThumbCache') do |_c,_|
          Dir.glob(File.join(THUMB_DIR, '*')).each { |p| File.delete(p) if File.file?(p) }
          @dlg.execute_script('EA.toast("Thumbnail-Cache geleert")') rescue nil
          send_rows(@cache_rows) # aktualisiere Thumb-URIs
        end

        # Modell Sync
        @dlg.add_action_callback('selectPid'){ |_c, pid| select_by_pid(pid.to_i) }
        @dlg.add_action_callback('zoomPid'){ |_c, pid| zoom_by_pid(pid.to_i) }
        @dlg.add_action_callback('isolateTag'){ |_c, tag| isolate_tag(tag.to_s) }
        @dlg.add_action_callback('restoreTags'){ |_c,_| restore_tags }

        # Inspector (Attributes)
        @dlg.add_action_callback('getDefinitionAttrs'){ |_c, def_name| send_definition_attrs(def_name.to_s) }
        @dlg.add_action_callback('setDefinitionAttrs'){ |_c, payload|
          h = JSON.parse(payload.to_s) rescue {}
          set_definition_attrs(h['def_name'].to_s, h['attrs'] || {})
        }
        @dlg.add_action_callback('applyAttrsAllInstances'){ |_c, payload|
          h = JSON.parse(payload.to_s) rescue {}
          apply_attrs_all_instances(h['def_name'].to_s, h['attrs'] || {})
        }

        @dlg.add_action_callback('getInstanceAttrs'){ |_c, pid_s| send_instance_attrs(pid_s.to_i) }
        @dlg.add_action_callback('setInstanceAttrs'){ |_c, payload|
          h = JSON.parse(payload.to_s) rescue {}
          set_instance_attrs(h['pid'].to_i, h['attrs'] || {})
        }
      end

      def default_opts
        {
          'selection_only'=>false,
          'include_hidden'=>false,
          'only_types'=>'both',            # both|components|groups
          'only_visible_tags'=>false,
          'max_depth'=>20,
          'attr_keys'=>DEFAULT_KEYS,
          'decimals'=>DEFAULT_DEC,
          'count_mode'=>'instances'
        }
      end

      def parse_defs(defs_json)
        (JSON.parse(defs_json.to_s) rescue []).select { |n| n.is_a?(String) && !n.empty? }
      end

      # ---------------- Export ----------------
      def export_rows(rows_json, kind)
        rows = JSON.parse(rows_json.to_s, symbolize_names: true) rescue []
        case kind
        when :csv
          path = UI.savepanel('Export CSV', default_export_dir, default_filename('csv')); return unless path
          write_csv(path, rows)
          toast("CSV exportiert: #{File.basename(path)}")
        when :json
          path = UI.savepanel('Export JSON', default_export_dir, default_filename('json')); return unless path
          File.open(path, 'wb'){|f| f.write(JSON.pretty_generate(rows))}
          toast("JSON exportiert: #{File.basename(path)}")
        when :zip
          target = UI.savepanel('Export ZIP (CSV + Thumbs)', default_export_dir, "elementaro_export_#{ts}.zip"); return unless target
          tmpdir = File.join(Sketchup.temp_dir, "elementaro_export_#{Process.pid}_#{Time.now.to_i}")
          FileUtils.mkdir_p(tmpdir)
          csv_path = File.join(tmpdir, 'data.csv')
          write_csv(csv_path, rows)
          thumbs_dir = File.join(tmpdir, 'thumbs'); FileUtils.mkdir_p(thumbs_dir)
          defs = rows.map{|r| r[:definition_name]}.compact.uniq
          defs.each do |dn|
            pth = thumb_path(dn)
            FileUtils.cp(pth, File.join(thumbs_dir, File.basename(pth))) if !pth.empty? && File.exist?(pth)
          end
          zipped = false
          begin
            require 'zip'
            Zip::File.open(target, Zip::File::CREATE) do |zip|
              zip.add('data.csv', csv_path)
              Dir[File.join(thumbs_dir, '*')].each{|f| zip.add(File.join('thumbs', File.basename(f)), f)}
            end
            zipped = true
          rescue LoadError
            alt = target.sub(/\.zip\z/i,'')
            FileUtils.mkdir_p(alt)
            FileUtils.cp(csv_path, File.join(alt, 'data.csv'))
            Dir[File.join(thumbs_dir,'*')].each{|f|
              FileUtils.mkdir_p(File.join(alt,'thumbs')); FileUtils.cp(f, File.join(alt,'thumbs',File.basename(f)))
            }
            UI.messagebox("Hinweis: 'rubyzip' nicht verfügbar.\\nOrdner statt ZIP erstellt:\\n#{alt}")
          ensure
            FileUtils.rm_rf(tmpdir) rescue nil
          end
          toast(zipped ? "ZIP exportiert" : "Export-Ordner erstellt")
        end
      rescue => ex
        UI.messagebox("Export fehlgeschlagen:\\n#{ex.class}: #{ex.message}")
      end

      def default_export_dir
        m = Sketchup.active_model
        m.path.to_s.empty? ? Dir.home : File.dirname(m.path)
      end
      def default_filename(ext) = "elementaro_autoinfo_#{ts}.#{ext}"
      def ts = Time.now.strftime('%Y%m%d_%H%M%S')

      def write_csv(path, rows)
        File.open(path,'wb'){|f| f.write("\uFEFF")}
        headers = %w[
          row_id parent_key entity_type entity_kind level path parent_display
          definition_name instance_name tag
          sku variant unit price_eur owner supplier article_number description
          def_total_qty def_tag_qty def_total_price_eur def_tag_price_eur thumb pid
        ]
        CSV.open(path,'ab',force_quotes:true,col_sep:';') do |csv|
          csv << headers
          rows.each{ |r| csv << headers.map{|k| r[k.to_sym]} }
        end
      end

      # ---------------- Thumbnails ----------------
      def thumb_uri(def_name)
        p = thumb_path(def_name)
        p.empty? ? '' : "file:///#{p.tr('\\\\','/')}"
      end

      def thumb_path(def_name)
        return '' if def_name.to_s.empty?
        p = File.join(THUMB_DIR, def_name.gsub(/[^\w\-]+/, '_') + '.png')
        File.exist?(p) ? p : ''
      end

      def queue_thumbs(def_names, only_missing:)
        list = def_names.uniq.compact
        list.select! { |n| Sketchup.active_model.definitions[n] rescue false }
        list.select! { |n| thumb_path(n).empty? } if only_missing
        total = list.length
        done  = 0
        return to_js('EA.toast("Keine offenen Thumbnails")') if total.zero?

        to_js('EA.toast("Starte Thumbnail-Queue …")')
        to_js('EA.thumbProgress(0)')
        batch = 3
        timer_id = UI.start_timer(0.03, true) do
          begin
            processed = 0
            while processed < batch && !list.empty?
              n = list.shift
              begin
                ensure_thumb_for(n)
              rescue => e
                warn "[EA] thumb error #{n}: #{e.message}"
              end
              done += 1
              processed += 1
            end
            prog = ((done.to_f / total) * 100).round
            to_js("EA.thumbProgress(#{prog})")
            if list.empty?
              UI.stop_timer(timer_id)
              send_rows(@cache_rows) # aktualisiere Thumb-URIs
              to_js('EA.thumbsReady()')
            end
          rescue => e
            warn "[EA] queue timer err: #{e.message}"
            UI.stop_timer(timer_id) rescue nil
            to_js('EA.thumbsReady()')
          end
        end
      end

      def ensure_thumb_for(def_name)
        return unless def_name && !def_name.empty?
        return unless thumb_path(def_name).empty?
        defn = Sketchup.active_model.definitions[def_name] rescue nil
        return unless defn.is_a?(Sketchup::ComponentDefinition)
        make_thumb(defn)
      end

      def make_thumb(defn)
        model = Sketchup.active_model
        view  = model.active_view
        cam0  = view.camera
        sel0  = model.selection.to_a
        path  = File.join(THUMB_DIR, defn.name.gsub(/[^\w\-]+/, '_') + '.png')

        model.start_operation('EA Thumb', true)
        begin
          stage = model.entities.add_group
          t     = Geom::Transformation.new([1000000.mm, 0, 0])
          stage.entities.add_instance(defn, t)
          bb    = stage.bounds
          eye   = Geom::Point3d.new(bb.center.x + bb.width*1.4, bb.center.y + bb.height*1.4, bb.center.z + bb.depth*1.4)
          view.camera = Sketchup::Camera.new(eye, bb.center, Z_AXIS)
          view.zoom(stage)
          view.write_image(path, 384, 384, true, 1.0)
          stage.erase!
        ensure
          model.selection.clear; model.selection.add(sel0)
          view.camera = cam0
          model.commit_operation
        end
        path
      rescue => ex
        warn "[EA] make_thumb #{defn&.name}: #{ex.message}"
        nil
      end

      # ---------------- Scan/Caching (ITERATIV) ----------------
      def scan_with_cache(opts)
        # Normalisiere
        opts = {
          'selection_only'=>!!opts['selection_only'],
          'include_hidden'=>!!opts['include_hidden'],
          'only_types'=>(opts['only_types']||'both'),
          'only_visible_tags'=>!!opts['only_visible_tags'],
          'max_depth'=> [[(opts['max_depth']||20).to_i,0].max, MAX_DEPTH_HARD].min,
          'attr_keys'=> (opts['attr_keys']||DEFAULT_KEYS).map{|k| k.to_s.strip}.reject(&:empty?),
          'decimals'=> (opts['decimals']||DEFAULT_DEC).to_i.clamp(0,6),
          'count_mode'=> (opts['count_mode']||'instances')
        }

        if @cache_rows && @cache_opts == opts && !@model_dirty
          return @cache_rows
        end

        rows = scan_iterative(opts)
        # Aggregation
        counts_def, counts_deftag = Hash.new(0), Hash.new(0)
        sum_def, sum_deftag       = Hash.new(0.0), Hash.new(0.0)
        rows.each do |r|
          kd  = r[:definition_name]; kdt = [r[:definition_name], r[:tag]]
          counts_def[kd] += 1; counts_deftag[kdt] += 1
          price = (r[:price_eur]||0).to_f
          sum_def[kd] += price; sum_deftag[kdt] += price
        end
        rows.each do |r|
          kd  = r[:definition_name]; kdt = [r[:definition_name], r[:tag]]
          r[:def_total_qty]       = counts_def[kd]
          r[:def_tag_qty]         = counts_deftag[kdt]
          r[:def_total_price_eur] = sum_def[kd].round(opts['decimals'])
          r[:def_tag_price_eur]   = sum_deftag[kdt].round(opts['decimals'])
          r[:thumb]               = thumb_uri(r[:definition_name])
        end
        assign_tree_ids!(rows)
        @cache_rows   = rows
        @cache_opts   = opts
        @defs_summary = build_defs_summary(rows) # für Katalog
        @model_dirty  = false
        rows
      end

      def scan_iterative(opts)
        @cancel_scan = false
        m    = Sketchup.active_model
        base = opts['selection_only'] ? m.selection.to_a : m.entities.to_a

        rows    = []
        visited = {}
        stack   = base.reverse.map{|e| [e, [], 0] } # [entity, parent_chain (names), depth]

        until stack.empty?
          e, chain, depth = stack.pop
          next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          next if depth > opts['max_depth']

          # Filter Typen
          if opts['only_types']=='components' && !e.is_a?(Sketchup::ComponentInstance) then next end
          if opts['only_types']=='groups'     && !e.is_a?(Sketchup::Group)             then next end

          # Sichtbarkeit/Tags
          unless opts['include_hidden']
            next if (e.hidden? rescue false)
            next if !(e.layer.visible? rescue true)
          end
          if opts['only_visible_tags']
            next if !(e.layer.visible? rescue true)
          end

          key = "#{e.persistent_id}@#{depth}"
          next if visited[key]; visited[key] = true

          defn = if e.respond_to?(:definition) && e.definition
                   e.definition
                 elsif e.respond_to?(:entities) && e.entities.respond_to?(:parent)
                   e.entities.parent
                 else
                   nil
                 end

          type      = e.is_a?(Sketchup::Group) ? 'Group' : 'Component'
          kind      = (type=='Component' && depth>=1) ? 'Subcomponent' : (type=='Group' ? 'Group' : 'Component')
          def_name  = (defn&.name || '').to_s
          inst_name = e.name.to_s
          tag_name  = (e.layer&.name || '').to_s
          display   = inst_name.empty? ? def_name : inst_name
          path      = (chain + [display]).join(' / ')
          parent    = chain.last || ''

          attrs = defn ? read_attrs(defn) : {}
          attrs.merge!(read_attrs(e))
          picked = pick(attrs, (opts['attr_keys']||[]))
          price  = (picked['price_eur']||0).to_f

          rows << {
            entity_type: type,
            entity_kind: kind,
            level: depth,
            path: path,
            parent_display: parent,
            definition_name: def_name,
            instance_name: inst_name,
            tag: tag_name,
            price_eur: price,
            pid: e.persistent_id
          }.merge(sym_down(picked))

          # Kinder pushen (Definition je Instanz) – umgekehrt für natürliche Reihenfolge
          if defn && defn.respond_to?(:entities)
            children = defn.entities.to_a
            children.reverse_each do |child|
              stack.push([child, chain + [display], depth+1])
            end
          end
        end

        rows
      end

      def read_attrs(obj)
        out = {}
        dicts = obj.respond_to?(:attribute_dictionaries) ? obj.attribute_dictionaries : nil
        return out unless dicts
        dicts.each{|d| next unless d; d.each_pair{|k,v| out[k.to_s]=v }}
        out
      end

      def pick(hash, keys)
        norm = {}; hash.each{|k,v| norm[k.to_s.downcase] = v }
        out  = {}; keys.each{|k| kk=k.to_s.downcase; out[k] = norm[kk] if norm.key?(kk) }
        out
      end

      def sym_down(h); h.each_with_object({}){|(k,v),o| o[k.to_s.downcase.to_sym]=v}; end

      def assign_tree_ids!(rows)
        rows.each_with_index do |r, i|
          parts = (r[:path]||'').split(' / ')
          r[:row_id] = i+1
          r[:parent_key] = parts[0...-1].join(' / ')
        end
      end

      # -------- Definitions-Katalog (für neue Ansicht) --------
      def build_defs_summary(rows)
        h = {} # def_name => details
        rows.each do |r|
          dn = r[:definition_name]; next if dn.to_s.empty?
          ent = (h[dn] ||= {
            definition_name: dn,
            entity_kinds:    {},
            count_instances: 0,
            sample_tag:      r[:tag],
            price_eur:       r[:price_eur] || 0,
            thumb:           thumb_uri(dn)
          })
          ent[:entity_kinds][r[:entity_kind]] = true
          ent[:count_instances] += 1
          ent[:price_eur] = r[:price_eur] if (r[:price_eur]||0) > (ent[:price_eur]||0)
        end
        h.values.sort_by{|x| x[:definition_name].downcase }
      end

      def send_defs_summary
        return unless @dlg && @dlg.visible?
        if @defs_summary
          @dlg.execute_script("EA.receiveDefs(#{JSON.generate(@defs_summary)})")
        else
          # Falls noch nicht gescannt
          scan_with_cache(@cache_opts || default_opts)
          @dlg.execute_script("EA.receiveDefs(#{JSON.generate(@defs_summary || [])})")
        end
      rescue => ex
        warn "[EA] send_defs_summary: #{ex.message}"
      end

      # ---------------- Modell-Sync ----------------
      def select_by_pid(pid)
        e = Sketchup.active_model.find_entity_by_persistent_id(pid) rescue nil
        return unless e
        m = Sketchup.active_model
        m.selection.clear; m.selection.add(e)
        push_selection
      end

      def zoom_by_pid(pid)
        e = Sketchup.active_model.find_entity_by_persistent_id(pid) rescue nil
        return unless e
        Sketchup.active_model.active_view.zoom(e.bounds)
        select_by_pid(pid)
      end

      def isolate_tag(tag_name)
        return if tag_name.to_s.empty?
        layers = Sketchup.active_model.layers
        snapshot = layers.map{|ly| {'tag'=>ly.name, 'visible'=>ly.visible?}}
        @tag_vis_stack << snapshot
        layers.each{|ly| ly.visible = (ly.name==tag_name) rescue nil}
      end

      def restore_tags
        snap = @tag_vis_stack.pop; return unless snap
        layers = Sketchup.active_model.layers
        snap.each do |h|
          ly = layers[h['tag']] rescue nil
          ly.visible = !!h['visible'] rescue nil if ly
        end
      end

      def push_selection
        return unless @dlg && @dlg.visible?
        sel = Sketchup.active_model.selection.to_a
        pids = sel.map{|e| e.respond_to?(:persistent_id) ? e.persistent_id : nil}.compact
        to_js("EA.receiveSelection(#{JSON.generate(pids)})")
      rescue => ex
        warn "[EA] push_selection: #{ex.message}"
      end

      # ---------------- Inspector I/O ----------------
      def send_definition_attrs(def_name)
        defn = Sketchup.active_model.definitions[def_name] rescue nil
        return unless defn
        attrs = read_attrs(defn)
        to_js("EA.receiveDefinitionAttrs(#{JSON.generate({'def_name'=>def_name, 'attrs'=>attrs})})")
      end

      def set_definition_attrs(def_name, attrs)
        defn = Sketchup.active_model.definitions[def_name] rescue nil
        return unless defn && attrs.is_a?(Hash)
        write_attrs(defn, attrs)
        @model_dirty = true
        toast("Definition gespeichert")
        send_rows(scan_with_cache(@cache_opts || default_opts))
      rescue => ex
        UI.messagebox("Fehler: #{ex.message}")
      end

      def send_instance_attrs(pid)
        e = Sketchup.active_model.find_entity_by_persistent_id(pid) rescue nil
        return unless e
        attrs = read_attrs(e)
        to_js("EA.receiveInstanceAttrs(#{JSON.generate({'pid'=>pid, 'attrs'=>attrs})})")
      end

      def set_instance_attrs(pid, attrs)
        e = Sketchup.active_model.find_entity_by_persistent_id(pid) rescue nil
        return unless e && attrs.is_a?(Hash)
        write_attrs(e, attrs)
        @model_dirty = true
        toast("Instanz gespeichert")
        send_rows(scan_with_cache(@cache_opts || default_opts))
      rescue => ex
        UI.messagebox("Fehler: #{ex.message}")
      end

      def apply_attrs_all_instances(def_name, attrs)
        return unless attrs.is_a?(Hash) && !attrs.empty?
        cnt = 0
        Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).each do |ci|
          next unless ci.definition && ci.definition.name == def_name
          write_attrs(ci, attrs); cnt += 1
        end
        @model_dirty = true
        to_js("EA.toast('Auf #{cnt} Instanzen angewendet')")
        send_rows(scan_with_cache(@cache_opts || default_opts))
      end

      def write_attrs(obj, attrs)
        %w[dynamic_attributes elementaro].each do |dict|
          attrs.each { |k,v| obj.set_attribute(dict, k.to_s, v) }
        end
      end

      # ---------------- Helpers ----------------
      def send_rows(rows)
        return unless @dlg && @dlg.visible?
        if rows.length <= CHUNK_SIZE
          to_js("EA.receiveRows(#{JSON.generate(rows)})")
        else
          to_js("EA.receiveRowsStart(#{rows.length})")
          rows.each_slice(CHUNK_SIZE){|sl| to_js("EA.receiveRowsChunk(#{JSON.generate(sl)})")}
          to_js('EA.receiveRowsEnd()')
        end
      rescue => ex
        warn "[EA] send_rows: #{ex.message}"
      end

      def to_js(js); @dlg.execute_script(js) rescue nil; end
      def toast(msg); to_js("EA.toast(#{JSON.generate(msg)})"); end

      # ---------------- Menü ----------------
      unless defined?($ea_menu_added) && $ea_menu_added
        $ea_menu_added = true
        (UI.menu('Extensions') rescue UI.menu('Plugins'))
          .add_submenu('Elementaro')
          .add_item('AutoInfo (Panel)'){ ElementaroInfo.show_panel }
      end
end
