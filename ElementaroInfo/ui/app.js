    // Elementaro AutoInfo UI (app.js)

    const SUI = window.sketchup || {};
    if (SUI.web_ready) SUI.web_ready();

    const DEFAULT_COLS = [
      ['tree',''],['thumb','Bild'],
      ['entity_kind','Entität'],['definition_name','Definition'],['instance_name','Instanz'],
      ['tag','Tag'],['price_eur','Stückpreis'],['owner','Eigentümer'],['supplier','Lieferant'],
      ['sku','SKU'],['variant','Variante'],['unit','Einheit'],['article_number','Artikel-Nr.'],
      ['def_total_qty','Menge gesamt'],['def_tag_qty','Menge je Tag'],
      ['def_total_price_eur','Summe (Def.)'],['def_tag_price_eur','Summe je Tag']
    ];

    function loadJSON(k, def){ try{ return JSON.parse(localStorage.getItem(k)||JSON.stringify(def)); }catch(_){ return def; } }
    function saveJSON(k, v){ localStorage.setItem(k, JSON.stringify(v)); }
    function loadLS(k, def){ const v = localStorage.getItem(k); return v==null? def : v; }
    function debounce(fn, delay){ let t; return (...a)=>{ clearTimeout(t); t=setTimeout(()=>fn(...a), delay); }; }

    function loadCols(){
      const saved = loadJSON('EA_COLS', null);
      if(!saved){ return DEFAULT_COLS.map(c=>[c[0], c[1], true]); }
      // Build ordered list, include any new columns from defaults
      const order = saved.map(r=>r[0]).concat(
        DEFAULT_COLS.map(c=>c[0]).filter(k=>!saved.find(r=>r[0]===k))
      );
      const labelMap = new Map(DEFAULT_COLS.map(c=>[c[0], c[1]]));
      const visMap = new Map(saved.map(r=>[r[0], r[2]!==false]));
      return order.map(k=>[k, labelMap.get(k)||k, visMap.has(k)?visMap.get(k):true]);
    }

    let COLS = loadCols();
    let visibleCols = new Set(COLS.filter(c=>c[2]!==false).map(c=>c[0]));

    let allRows=[], rowsVersion=0;
    let defsCatalog=[];
    let currentVis=[];

    let filterCacheKey = '';
    let cachedVisible = [];

    let expanded=new Set();
    let rowHeight=30, buffer=8;
    let selectedPids=new Set();
    let followSelection=false;
    let decimals = parseInt(loadLS('EA_DECIMALS', '2'), 10) || 2;

    let pinnedDefs  = new Set(loadJSON('EA_PINNED', []));
    let excludedDefs= new Set(loadJSON('EA_EXCLUDED', []));

    const $ = sel => document.querySelector(sel);

    function buildHeader(){
      const tr = $('#thead'); tr.innerHTML='';
      COLS.forEach(([key,label])=>{
        const th=document.createElement('th');
        th.textContent=label;
        th.dataset.key = key;
        if(key!=='tree'){
          th.classList.add('draggable'); th.draggable=true;
          th.title='Spalte verschieben (Drag). Sichtbarkeit im Menü „Spalten“ ändern.';
        }
        tr.appendChild(th);
      });
      let dragKey=null;
      tr.addEventListener('dragstart', e=>{
        dragKey = e.target.dataset.key || null;
        e.dataTransfer.setData('text/plain', dragKey);
      });
      tr.addEventListener('dragover', e=>{ e.preventDefault(); });
      tr.addEventListener('drop', e=>{
        e.preventDefault();
        const from = dragKey, to = e.target.dataset.key;
        if(!from || !to || from===to) return;
        const i = COLS.findIndex(c=>c[0]===from);
        const j = COLS.findIndex(c=>c[0]===to);
        const [moved] = COLS.splice(i,1);
        COLS.splice(j,0,moved);
        saveCols();
        buildHeader();
        render();
      });
    }
    buildHeader();

    $('#btnColumns').onclick = ()=>{
      const menu = $('#colsMenu'); const body = $('#colsBody'); body.innerHTML='';
      COLS.forEach(([k,l])=>{
        const id='col_'+k;
        const wrap=document.createElement('label');
        wrap.innerHTML=`<input type="checkbox" id="${id}" ${visibleCols.has(k)?'checked':''}> ${l}`;
        body.appendChild(wrap);
      });
      $('#colsClose').onclick = ()=>{
        COLS.forEach(([k,_])=>{
          const cb = document.getElementById('col_'+k);
          if(!cb) return;
          if(cb.checked) visibleCols.add(k); else visibleCols.delete(k);
        });
        saveCols(); buildHeader(); render(); menu.style.display='none';
      };
      menu.style.display='block';
      document.addEventListener('click', (ev)=>{ if(!menu.contains(ev.target) && ev.target.id!=='btnColumns'){ menu.style.display='none'; }}, {once:true});
    };

    function saveCols(){
      const toSave = COLS.map(([k,l])=>[k,l, visibleCols.has(k)]);
      saveJSON('EA_COLS', toSave);
    }

    function refreshChips(){
      const ch=$('#chips'); ch.innerHTML='';
      const map = currentFilterMap();
      Object.entries(map).forEach(([k,v])=>{
        if(!v) return;
        const d=document.createElement('div'); d.className='tagx';
        d.innerHTML = `<span>${k}: ${String(v).substring(0,60)}</span><span class="x">✕</span>`;
        d.querySelector('.x').onclick=()=>clearFilterKey(k);
        ch.appendChild(d);
      });
    }
    function clearFilterKey(k){
      if(k==='Suche') $('#q').value='';
      if(k==='Entität') $('#fType').value='';
      if(k==='Tag') $('#fTag').value='';
      if(k==='nur unvollständig') $('#fIncomplete').checked=false;
      if(k==='nur Merkliste') $('#onlyPinned').checked=false;
      render();
    }
    function currentFilterMap(){
      return {
        'Suche': ($('#q').value||'').trim(),
        'Entität': $('#fType').value||'',
        'Tag': $('#fTag').value||'',
        'nur unvollständig': $('#fIncomplete').checked? 'ja':'',
        'nur Merkliste': $('#onlyPinned').checked? 'ja':'',
      };
    }

    const EA = {
      toast: (msg)=>{
        const box = $('#toasts');
        const el = document.createElement('div'); el.className='ea-toast'; el.textContent=msg;
        box.appendChild(el); setTimeout(()=>{ el.style.opacity='0'; setTimeout(()=>el.remove(), 300); }, 2200);
      },
      receiveRows: rows => { allRows = rows||[]; rowsVersion++; afterReceive(); },
      receiveRowsStart: total => { allRows=[]; },
      receiveRowsChunk: slice => { allRows = allRows.concat(slice||[]); },
      receiveRowsEnd: ()=> { rowsVersion++; afterReceive(); },
      receiveSelection: pids => { selectedPids = new Set(pids||[]); if($('#followSel').checked) render(); },
      receiveDefinitionAttrs: payload => renderDefEditor(payload),
      receiveInstanceAttrs: payload => renderInstEditor(payload),
      receiveDefs: list => { defsCatalog = list||[]; drawCatalog(); },
      thumbsReady: ()=> { toggleLoading(false); EA.toast('Thumbnails fertig'); },
      thumbProgress: p => { toggleLoading(true, `Thumbnails… ${p}%`); }
    };
    window.EA = EA;

    // Buttons
    $('#btnScan').onclick = requestData;
    $('#btnExportCsv').onclick  = ()=> SUI.exportCsv  && SUI.exportCsv(JSON.stringify(currentVisibleRows()));
    $('#btnExportJson').onclick = ()=> SUI.exportJson && SUI.exportJson(JSON.stringify(currentVisibleRows()));
    $('#btnExportZip').onclick  = ()=> SUI.exportZip  && SUI.exportZip(JSON.stringify(currentVisibleRows()));

    $('#btnCollapseAll').onclick = ()=>{ expanded=new Set(); render(); };
    $('#btnExpandAll').onclick   = ()=>{ expanded=new Set(allRows.map(r=>r.path)); render(); };
    $('#btnThumbsMissing').onclick = ()=>{ const defs=uniqueDefs(); toggleLoading(true); SUI.thumbsMissing && SUI.thumbsMissing(JSON.stringify(defs)); };
    $('#btnThumbsAll').onclick     = ()=>{ const defs=uniqueDefs(); toggleLoading(true); SUI.thumbsAll && SUI.thumbsAll(JSON.stringify(defs)); };
    $('#btnThumbsClear').onclick   = ()=> SUI.clearThumbCache && SUI.clearThumbCache();
    $('#btnRestoreTags').onclick   = ()=> SUI.restoreTags && SUI.restoreTags();

    const handleSearchInput = debounce(()=>{ render(); refreshChips(); saveFilters(); }, 200);
    $('#q').oninput = handleSearchInput;
    $('#onlyPinned').onchange = ()=>{ render(); refreshChips(); saveFilters(); };
    $('#fType').onchange = ()=>{ render(); refreshChips(); saveFilters(); };
    $('#fTag').onchange  = ()=>{ render(); refreshChips(); saveFilters(); };
    $('#fIncomplete').onchange = ()=>{ render(); refreshChips(); saveFilters(); };

    $('#followSel').onchange = (e)=>{ followSelection=e.target.checked; saveFilters(); if(followSelection) SUI.pullSelection && SUI.pullSelection(); render(); };

    $('#selOnly').onchange = requestData;
    $('#inclHidden').onchange = requestData;
    $('#onlyVisibleTags').onchange = requestData;
    $('#onlyTypes').onchange = requestData;
    $('#maxDepth').oninput  = (e)=> $('#maxDepthVal').textContent = e.target.value;
    $('#maxDepth').onchange = requestData;
    $('#attrKeys').onchange = ()=>{ saveFilters(); requestData(); };
    $('#decimals').onchange = (e)=>{ decimals=parseInt(e.target.value||2,10); localStorage.setItem('EA_DECIMALS', String(decimals)); render(); };
    $('#countMode').onchange = render;

    const tabs = Array.from(document.querySelectorAll('.ea-tabs .tab'));
    function activateTab(t){
      tabs.forEach(x=>{
        const active = x===t;
        x.classList.toggle('active', active);
        x.setAttribute('aria-selected', active? 'true':'false');
        x.setAttribute('tabindex', active? '0':'-1');
        const view=document.getElementById(x.getAttribute('aria-controls'));
        if(view) view.style.display = active? '' : 'none';
      });
      if(t.dataset.tab==='catalog') drawCatalog();
    }
    tabs.forEach(t=>{
      t.addEventListener('click', ()=>activateTab(t));
      t.addEventListener('keydown', e=>{
        if(e.key==='ArrowRight' || e.key==='ArrowLeft'){
          e.preventDefault();
          const dir = e.key==='ArrowRight'?1:-1;
          let idx = tabs.indexOf(t) + dir;
          if(idx<0) idx = tabs.length-1;
          if(idx>=tabs.length) idx = 0;
          tabs[idx].focus();
          activateTab(tabs[idx]);
        } else if(e.key==='Enter'){
          e.preventDefault();
          activateTab(t);
        }
      });
    });
    activateTab(document.querySelector('.ea-tabs .tab.active') || tabs[0]);

    (function init(){
      $('#attrKeys').value = loadLS('EA_ATTRS', 'sku,variant,unit,price_eur,owner,supplier,article_number,description');
      $('#decimals').value = loadLS('EA_DECIMALS', '2');
      const fs = loadJSON('EA_FILTERS', {});
      $('#fType').value = fs.fType || '';
      $('#fTag').value  = fs.fTag  || '';
      $('#q').value     = fs.q     || '';
      $('#fIncomplete').checked = !!fs.fIncomplete;
      $('#onlyPinned').checked   = !!fs.onlyPinned;
      $('#followSel').checked    = !!fs.followSel;
      refreshChips();
    })();

    function saveFilters(){
      saveJSON('EA_FILTERS', {
        fType: $('#fType').value,
        fTag: $('#fTag').value,
        q: $('#q').value,
        fIncomplete: $('#fIncomplete').checked,
        onlyPinned: $('#onlyPinned').checked,
        followSel: $('#followSel').checked
      });
      localStorage.setItem('EA_ATTRS', $('#attrKeys').value);
    }

    function requestData(){
      const payload = {
        selection_only: $('#selOnly').checked,
        include_hidden: $('#inclHidden').checked,
        only_types: $('#onlyTypes').value,
        only_visible_tags: $('#onlyVisibleTags').checked,
        max_depth: parseInt($('#maxDepth').value,10),
        attr_keys: ($('#attrKeys').value||'').split(',').map(s=>s.trim()).filter(Boolean),
        decimals: parseInt($('#decimals').value||2,10),
        count_mode: $('#countMode').value
      };
      toggleLoading(true, 'Scanne Modell …');
      SUI.requestData && SUI.requestData(JSON.stringify(payload));
    }

    function afterReceive(){
      const sel=$('#fTag');
      const tags=[...new Set(allRows.map(r=>r.tag).filter(Boolean))].sort();
      const cur=sel.value;
      sel.innerHTML='<option value=\"\">alle</option>'+tags.map(t=>`<option>${t}</option>`).join('');
      if(tags.includes(cur)) sel.value=cur;

      const roots=new Set(allRows.filter(r=>!r.parent_key).map(r=>r.path));
      expanded = roots;
      toggleLoading(false);
      render();
    }

    function filterKey(){
      return JSON.stringify({
        q: $('#q').value || '',
        type: $('#fType').value || '',
        tag: $('#fTag').value || '',
        incomplete: $('#fIncomplete').checked,
        onlyPinned: $('#onlyPinned').checked,
        followSel: $('#followSel').checked,
        selSize: $('#followSel').checked ? selectedPids.size : 0,
        excluded: [...excludedDefs].sort(),
        pinned:   [...pinnedDefs].sort(),
        rowsVer: rowsVersion
      });
    }

    function computeVisible(){
      const q=( $('#q').value || '' ).toLowerCase();
      const ent=$('#fType').value;
      const tag=$('#fTag').value;
      const onlyBad=$('#fIncomplete').checked;
      const onlyPinned=$('#onlyPinned').checked;

      const out=[];
      for (let i=0;i<allRows.length;i++){
        const r=allRows[i];
        if(ent && r.entity_kind!==ent) continue;
        if(tag && r.tag!==tag) continue;
        if(onlyBad){
          const bad = (!r.tag || !r.tag.trim()) || (!r.owner || !r.owner.trim()) || (!r.price_eur || Number(r.price_eur)==0);
          if(!bad) continue;
        }
        if($('#followSel').checked && selectedPids.size && !selectedPids.has(r.pid)) continue;
        if(excludedDefs.has(r.definition_name)) continue;
        if(onlyPinned && !pinnedDefs.has(r.definition_name)) continue;
        if(q){
          const hay=(r.definition_name+' '+r.instance_name+' '+(r.tag||'')+' '+r.path+' '+(r.description||'')).toLowerCase();
          if(hay.indexOf(q)===-1) continue;
        }
        out.push(r);
      }
      return out;
    }

    function visibleRows(){
        const key = filterKey();
        if(key !== filterCacheKey){
          cachedVisible = computeVisible();
          filterCacheKey = key;
        }
        return cachedVisible;
      }

    const listWrap=$('#listWrap'), tbody=$('#tbody'), spacer=$('#spacer');
    let scrollRAF=null;
    listWrap.addEventListener('scroll', ()=>{
      if(scrollRAF) return;
      scrollRAF = requestAnimationFrame(()=>{
        scrollRAF=null;
        drawWindow();
      });
    });

    function render(){
      refreshChips();
      const vis = visibleRows();
      currentVis = vis;

      const defs=new Map();
      const types=new Set();
      vis.forEach(r=>{
        types.add(r.entity_kind);
        const d=r.definition_name;
        if(d && !defs.has(d)){
          defs.set(d, Number(r.def_total_price_eur||0));
        }
      });
      const sumPrice=[...defs.values()].reduce((acc,v)=>acc+v,0);
      $('#kpiCount').textContent = `Zeilen: ${vis.length.toLocaleString()}`;
      $('#kpiTypes').textContent = `Entitäten: ${[...types].join(', ')||'-'}`;
      $('#kpiDefs').textContent  = `Definitionen: ${defs.size.toLocaleString()}`;
      $('#kpiPrice').textContent = `Summe (Def.): ${sumPrice.toFixed(decimals)} €`;

      const exp = vis.filter(isVisibleByExpand);
      spacer.style.height = (exp.length * rowHeight)+'px';
      drawWindow();
      drawCards();
      drawCatalog();
      renderTray();
    }

    function isVisibleByExpand(r){
      if(!r.parent_key) return true;
      const parts=(r.path||'').split(' / '); let acc='';
      for(let i=0;i<parts.length-1;i++){
        acc = (i===0)?parts[0]:(acc+' / '+parts[i]);
        if(!expanded.has(acc)) return false;
      }
      return true;
    }

    function drawWindow(){
      const vis = currentVis.filter(isVisibleByExpand);
      const scrollTop=listWrap.scrollTop, height=listWrap.clientHeight;
      const start=Math.max(0, Math.floor(scrollTop/rowHeight)-buffer);
      const end=Math.min(vis.length, Math.ceil((scrollTop+height)/rowHeight)+buffer);

      tbody.innerHTML='';
      for(let i=start;i<end;i++){
        const r = vis[i];
        const tr=document.createElement('tr');
        tr.style.position='absolute'; tr.style.top=(i*rowHeight)+'px';
        tr.dataset.pid=r.pid||''; tr.dataset.tag=r.tag||''; tr.dataset.index=i; tr.dataset.def=r.definition_name||'';

        tr.oncontextmenu=(ev)=>{ ev.preventDefault(); showRowMenu(ev.pageX, ev.pageY, tr); };

        COLS.forEach(([k,l,visible])=>{
          if(!visibleCols.has(k) && k!=='tree') return;
          const td=document.createElement('td'); td.style.height=(rowHeight-2)+'px';
          td.onclick=(ev)=>{ navigator.clipboard.writeText(td.textContent||''); ev.stopPropagation(); };

          if(k==='tree'){
            const wrap=document.createElement('div'); wrap.style.display='flex'; wrap.style.alignItems='center'; wrap.style.gap='6px';
            const indent=document.createElement('span'); indent.style.paddingLeft=(6+(parseInt(r.level||0,10)*12))+'px';
            const isExp = expanded.has(r.path);
            const hasChildren = allRows.some(x=>x.parent_key===r.path);
            const btn=document.createElement('span'); btn.style.cursor= hasChildren ? 'pointer' : 'default';
            btn.textContent = hasChildren ? (isExp?'▾':'▸') : '•';
            btn.onclick=(ev)=>{ if(!hasChildren) return; ev.stopPropagation(); toggleExpand(r.path); };

            const star=document.createElement('span'); star.style.cursor='pointer'; star.title='Merken';
            star.textContent = pinnedDefs.has(r.definition_name)?'★':'☆';
            star.onclick=(ev)=>{ ev.stopPropagation(); togglePin(r.definition_name); };

            const eye=document.createElement('span'); eye.style.cursor='pointer'; eye.title='Ausblenden';
            eye.textContent='🚫'; eye.onclick=(ev)=>{ ev.stopPropagation(); toggleExclude(r.definition_name); };

            const sel=document.createElement('button'); sel.textContent='Auswählen'; sel.onclick=(ev)=>{ ev.stopPropagation(); SUI.selectPid && SUI.selectPid(r.pid); };
            const zm=document.createElement('button'); zm.textContent='Zoomen';    zm.onclick=(ev)=>{ ev.stopPropagation(); SUI.zoomPid && SUI.zoomPid(r.pid); };
            const iso=document.createElement('button'); iso.textContent='Tag isolieren'; iso.onclick=(ev)=>{ ev.stopPropagation(); if(r.tag) SUI.isolateTag && SUI.isolateTag(r.tag); };

            wrap.appendChild(indent); wrap.appendChild(btn); wrap.appendChild(star); wrap.appendChild(eye); wrap.appendChild(sel); wrap.appendChild(zm); wrap.appendChild(iso);
            td.appendChild(wrap);
          } else if(k==='thumb'){
            const img=document.createElement('img'); img.className='thumb'; if(r.thumb) img.src=r.thumb; td.appendChild(img);
          } else if(k==='entity_kind'){
            const s=document.createElement('span'); s.className='pill type-'+r.entity_kind; s.textContent=r.entity_kind; td.appendChild(s);
          } else if(k==='definition_name'){
            const warn = (!r.tag || !r.tag.trim()) || (!r.owner || !r.owner.trim()) || (!r.price_eur || Number(r.price_eur)==0);
            td.className='indent'; td.style.setProperty('--indent',(parseInt(r.level||0,10)*12)+'px');
            td.innerHTML = `<span${warn?' class="warn"':''}>${r.definition_name||''}</span>`;
          } else if(k.endsWith('price_eur')){
            const v=r[k]; td.textContent=(v==null||v==='')?'': Number(v).toFixed(decimals);
          } else {
            td.textContent = r[k]==null? '': r[k];
          }
          tr.appendChild(td);
        });
        tbody.appendChild(tr);
      }
    }
    function toggleExpand(path){ if(expanded.has(path)) expanded.delete(path); else expanded.add(path); drawWindow(); }

    function showRowMenu(x,y, tr){
      const menu = document.getElementById('eaRowMenu') || (()=> {
        const m = document.createElement('div'); m.id='eaRowMenu'; m.className='ea-cols-menu'; m.style.width='220px';
        m.innerHTML = `
          <div class="head">Aktionen</div>
          <div class="body" style="padding:6px 10px">
            <button data-act="copy"   style="width:100%">Wert kopieren</button>
            <button data-act="select" style="width:100%">Im Modell auswählen</button>
            <button data-act="zoom"   style="width:100%">Dorthin zoomen</button>
            <button data-act="isolate"style="width:100%">Nur diesen Tag isolieren</button>
            <button data-act="export" style="width:100%">Export nur diese</button>
            <button data-act="hide"   style="width:100%">Zeile ausblenden</button>
          </div>`;
        document.body.appendChild(m);
        return m;
      })();
      menu.style.left=x+'px'; menu.style.top=y+'px'; menu.style.display='block';
        const r = currentVis.filter(isVisibleByExpand)[parseInt(tr.dataset.index,10)];

      menu.querySelectorAll('button').forEach(btn=>{
        btn.onclick = ()=>{
          const act = btn.dataset.act;
          if(act==='copy')   navigator.clipboard.writeText(tr.textContent||'');
          if(act==='select') SUI.selectPid && SUI.selectPid(r.pid);
          if(act==='zoom')   SUI.zoomPid && SUI.zoomPid(r.pid);
          if(act==='isolate' && r.tag) SUI.isolateTag && SUI.isolateTag(r.tag);
          if(act==='export') SUI.exportCsv && SUI.exportCsv(JSON.stringify([r]));
          if(act==='hide')   toggleExclude(r.definition_name);
          menu.style.display='none';
        };
      });
      document.addEventListener('click', ()=> menu.style.display='none', {once:true});
    }

    function drawCards(){
      if($('#cardsView').style.display==='none'){ $('#cards').innerHTML=''; return; }
      const cards=$('#cards'); cards.innerHTML='';
        const map={}; currentVis.forEach(r=>{ if(!excludedDefs.has(r.definition_name)) map[r.definition_name]=r; });
      Object.values(map).forEach(r=>{
        const d=document.createElement('div'); d.className='card';
        const img=document.createElement('img'); if(r.thumb) img.src=r.thumb;
        const col=document.createElement('div');
        col.innerHTML = `<div><strong>${r.definition_name||''}</strong></div>
                         <div class="muted">${r.entity_kind} • ${r.tag||'-'}</div>
                         <div class="muted">${Number(r.def_total_price_eur||0).toFixed(decimals)} €</div>`;
        d.appendChild(img); d.appendChild(col);
        d.onclick=()=> openDefInspector(r.definition_name);
        cards.appendChild(d);
      });
    }

    function openDefInspector(defName){ SUI.getDefinitionAttrs && SUI.getDefinitionAttrs(defName); }
    function renderDefEditor(payload){
      const defName=payload.def_name, attrs=payload.attrs||{};
      renderKV('Definition: '+defName, attrs, out=>{
        SUI.setDefinitionAttrs && SUI.setDefinitionAttrs(JSON.stringify({def_name:defName, attrs:out}));
      }, out=>{
        SUI.applyAttrsAllInstances && SUI.applyAttrsAllInstances(JSON.stringify({def_name:defName, attrs:out}));
      });
    }
    function renderInstEditor(payload){
      const pid=payload.pid, attrs=payload.attrs||{};
      renderKV('Instanz: '+pid, attrs, out=>{
        SUI.setInstanceAttrs && SUI.setInstanceAttrs(JSON.stringify({pid:pid, attrs:out}));
      });
    }
    function renderKV(title, attrs, onSave, onApplyAll){
      const insp=$('#inspBody');
      const keys=Object.keys(attrs||{}); const known=['sku','variant','unit','price_eur','owner','supplier','article_number','description'];
      known.forEach(k=>{ if(!keys.includes(k)) keys.unshift(k); });
      insp.innerHTML = `<h3>${title}</h3><div class="small muted">DC- & benutzerdef. Attribute.</div><div id="kv"></div>
                        <div style="margin-top:8px;display:flex;gap:6px">
                          <button id="addRow">Feld hinzufügen</button>
                          <button id="saveRows" class="primary">Speichern</button>
                        </div>`;
      const kv=$('#kv');
      (keys.length?keys:['']).forEach(k=>{
        const v = (attrs||{})[k] ?? '';
        const row=document.createElement('div'); row.className='kv';
        row.innerHTML=`<input type="text" value="${k}" placeholder="key"><input type="text" value="${v}" placeholder="value">`;
        kv.appendChild(row);
      });
      $('#addRow').onclick=()=>{
        const row=document.createElement('div'); row.className='kv';
        row.innerHTML=`<input type="text" placeholder="key"><input type="text" placeholder="value">`;
        kv.appendChild(row);
      };
      $('#saveRows').onclick=()=>{
        const out={}; kv.querySelectorAll('.kv').forEach(kv=>{
          const k=kv.children[0].value.trim(); const v=kv.children[1].value; if(k) out[k]=v;
        });
        onSave && onSave(out);
      };
      if(onApplyAll){
        const b=document.createElement('button'); b.textContent='Auf alle Instanzen anwenden'; b.style.marginTop='8px';
        b.onclick=()=>{
          const out={}; kv.querySelectorAll('.kv').forEach(kv=>{
            const k=kv.children[0].value.trim(); const v=kv.children[1].value; if(k) out[k]=v;
          });
          onApplyAll(out);
        };
        insp.appendChild(b);
      }
    }

    function drawCatalog(){
      if($('#catalogView').style.display==='none') return;
      const wrap=$('#catalog'); wrap.innerHTML='';
      if(!defsCatalog || !defsCatalog.length){ wrap.innerHTML='<div class="small muted">Noch keine Daten – „Jetzt scannen“ klicken.</div>'; return; }
      defsCatalog.forEach(d=>{
        const el=document.createElement('div'); el.className='catalog-card';
        const img=document.createElement('img'); if(d.thumb) img.src=d.thumb;
        const col=document.createElement('div');
        col.innerHTML = `<div><strong>${d.definition_name}</strong></div>
                         <div class="small muted">${Object.keys(d.entity_kinds||{}).join(', ')}</div>
                         <div class="small muted">Instanzen: ${d.count_instances}</div>`;
        el.appendChild(img); el.appendChild(col);
        el.onclick=()=> openDefInspector(d.definition_name);
        wrap.appendChild(el);
      });
    }

    function renderTray(){
      const pin=$('#pinTray'); pin.innerHTML='';
      const exc=$('#excludeTray'); exc.innerHTML='';
      [...pinnedDefs].sort().forEach(def=>{
        const el=document.createElement('div'); el.className='tagx'; el.innerHTML=`<span>★ ${def}</span><span class="x">✕</span>`;
        el.querySelector('.x').onclick=()=>togglePin(def); pin.appendChild(el);
      });
      [...excludedDefs].sort().forEach(def=>{
        const el=document.createElement('div'); el.className='tagx'; el.innerHTML=`<span>🚫 ${def}</span><span class="x">Wiederherstellen</span>`;
        el.querySelector('.x').onclick=()=>toggleExclude(def); exc.appendChild(el);
      });
    }
    function togglePin(def){ if(pinnedDefs.has(def)) pinnedDefs.delete(def); else pinnedDefs.add(def); saveJSON('EA_PINNED', [...pinnedDefs]); refreshChips(); renderTray(); render(); }
    function toggleExclude(def){ if(excludedDefs.has(def)) excludedDefs.delete(def); else excludedDefs.add(def); saveJSON('EA_EXCLUDED', [...excludedDefs]); refreshChips(); renderTray(); render(); }

    function uniqueDefs(){ const rows=currentVisibleRows(); return [...new Set(rows.map(r=>r.definition_name).filter(Boolean))]; }
    function currentVisibleRows(){ return currentVis.filter(isVisibleByExpand); }

    function toggleLoading(on, txt){
      const el=$('#loading'); el.style.display=on?'flex':'none';
      if(txt) el.querySelector('.box').textContent = txt;
    }
