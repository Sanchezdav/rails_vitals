// ─── Palette ────────────────────────────────────────────────────────────────
var COLOR_N1        = '#fc8181';   // red   — N+1 warnings
var COLOR_HEALTHY   = '#68d391';   // green — healthy / no issues
var COLOR_BELONGS   = '#9f7aea';   // purple — belongs_to macro
var COLOR_HAS_MANY  = '#f6ad55';   // orange — has_many / has_one macro
var COLOR_MUTED     = '#718096';   // grey  — secondary text
var COLOR_TEXT      = '#e2e8f0';   // white-ish — primary text
var COLOR_SURFACE   = '#1a202c';   // dark  — card surface
var COLOR_N1_BG     = '#2d1515';   // dark red — N+1 card background

// ─── Panel element IDs (shared by selectNode / closePanel) ──────────────────
var ID_PANEL        = 'assoc-panel';
var ID_PANEL_INNER  = 'assoc-panel-inner';
var ID_MODEL_NAME   = 'panel-model-name';
var ID_QUERY_COUNT  = 'panel-query-count';
var ID_AVG_TIME     = 'panel-avg-time';
var ID_N1_COUNT     = 'panel-n1-count';
var ID_ASSOCIATIONS = 'panel-associations';
var ID_N1_SECTION   = 'panel-n1-section';
var ID_N1_LIST      = 'panel-n1-list';
var ID_LINKS        = 'panel-links';

// ─── requests/show ──────────────────────────────────────────────────────────
function toggleDna(id) {
  var row = document.getElementById(id);
  if (row) {
    var isHidden = window.getComputedStyle(row).display === 'none';
    row.classList.remove('d-none');
    row.style.display = isHidden ? 'table-row' : 'none';
  }
}

function toggleCard(id, chevronId) {
  var card = document.getElementById(id);
  if (card) {
    var isHidden = window.getComputedStyle(card).display === 'none';
    card.classList.remove('d-none');
    card.style.display = isHidden ? (card.tagName === 'TABLE' ? 'table' : 'block') : 'none';
  }

  if (chevronId) {
    var chevron = document.getElementById(chevronId);
    if (chevron) {
      chevron.textContent = chevron.textContent === '▼' ? '▶' : '▼';
    }
  }
}

// ─── explains/show ──────────────────────────────────────────────────────────
function toggleExplanation(id) {
  var el = document.getElementById(id);
  if (el) {
    var isHidden = window.getComputedStyle(el).display === 'none';
    el.classList.remove('d-none');
    el.style.display = isHidden ? 'block' : 'none';
  }
}

// ─── associations/index ─────────────────────────────────────────────────────
// NODE_DATA, N1_PATH, and REQUEST_PATH are injected inline by the view as a data bridge.

function selectNode(nameJson) {
  var name = JSON.parse(nameJson);
  var node = NODE_DATA[name];
  if (!node) return;

  // Highlight selected node
  document.querySelectorAll('[id^="node-"]').forEach(function(el) {
    el.style.opacity = '0.4';
  });
  var el = document.getElementById('node-' + name);
  if (el) el.style.opacity = '1';

  // Populate panel header
  document.getElementById(ID_MODEL_NAME).textContent  = node.name;
  document.getElementById(ID_QUERY_COUNT).textContent = node.query_count;
  document.getElementById(ID_AVG_TIME).textContent    = node.avg_query_time_ms;

  var n1Count = node.n1_patterns.length;
  var n1El    = document.getElementById(ID_N1_COUNT);
  n1El.textContent = n1Count;
  n1El.style.color = n1Count > 0 ? COLOR_N1 : COLOR_HEALTHY;

  // Associations list
  var assocHtml = '';
  node.associations.forEach(function(a) {
    var macroColor = a.macro === 'belongs_to' ? COLOR_BELONGS : COLOR_HAS_MANY;
    var n1Badge    = a.has_n1
      ? badge(COLOR_N1, 'N+1')
      : '';
    var indexBadge = a.indexed
      ? badge(COLOR_HEALTHY, 'indexed')
      : badge(COLOR_HAS_MANY, '⚠ no index');

    assocHtml +=
      '<div style="padding:8px;background:' + COLOR_SURFACE + ';border-radius:4px;margin-bottom:6px;font-size:12px;">' +
        '<span style="color:' + macroColor + ';font-family:monospace;">' + a.macro + '</span>' +
        ' <span style="color:' + COLOR_TEXT + ';font-family:monospace;">:' + a.to_model.toLowerCase() + '</span>' +
        n1Badge +
        '<div style="color:' + COLOR_MUTED + ';font-size:10px;margin-top:4px;font-family:monospace;">' +
          'fk: ' + a.foreign_key + indexBadge +
        '</div>' +
      '</div>';
  });
  document.getElementById(ID_ASSOCIATIONS).innerHTML =
    assocHtml || '<div style="color:' + COLOR_MUTED + ';font-size:12px;">No associations</div>';

  // N+1 section
  var n1Section = document.getElementById(ID_N1_SECTION);
  if (n1Count > 0) {
    n1Section.style.display = 'block';
    var n1Html = '';
    node.n1_patterns.forEach(function(p) {
      n1Html +=
        '<div style="padding:8px;background:' + COLOR_N1_BG + ';border:1px solid ' + COLOR_N1 + '44;' +
                    'border-radius:4px;margin-bottom:6px;font-size:11px;">' +
          '<div style="color:' + COLOR_N1 + ';font-family:monospace;margin-bottom:4px;">' +
            p.occurrences + 'x detected' +
          '</div>' +
          (p.fix_suggestion
            ? '<div style="color:' + COLOR_HEALTHY + ';font-family:monospace;">Fix: ' + p.fix_suggestion + '</div>'
            : '') +
        '</div>';
    });
    document.getElementById(ID_N1_LIST).innerHTML = n1Html;
  } else {
    n1Section.style.display = 'none';
  }

  // Action links
  var linksHtml = '';
  if (n1Count > 0) {
    linksHtml +=
      '<a href="' + N1_PATH + '" ' +
         'style="display:block;background:' + COLOR_N1_BG + ';border:1px solid ' + COLOR_N1 + '66;' +
                'color:' + COLOR_N1 + ';padding:8px 12px;border-radius:4px;font-size:12px;' +
                'text-decoration:none;text-align:center;margin-top:8px;">' +
        'View N+1 patterns →' +
      '</a>';
  }
  document.getElementById(ID_LINKS).innerHTML = linksHtml;

  // Open panel
  document.getElementById(ID_PANEL).style.width       = '320px';
  document.getElementById(ID_PANEL_INNER).style.display = 'block';
}

function closePanel() {
  document.getElementById(ID_PANEL).style.width        = '0';
  document.getElementById(ID_PANEL_INNER).style.display = 'none';
  document.querySelectorAll('[id^="node-"]').forEach(function(el) {
    el.style.opacity = '1';
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
function badge(color, text) {
  return '<span style="background:' + color + '33;color:' + color + ';' +
         'font-size:9px;padding:1px 5px;border-radius:3px;margin-left:4px;">' +
         text + '</span>';
}
