// Physicl Hub Browser - usage statistics receiver (Google Apps Script, bound to the releases spreadsheet).
// Deploy: Extensions > Apps Script > paste this file > Deploy > New deployment > Web app,
//   Execute as: Me, Who has access: Anyone. The Web app URL is statsUrl in PHB_Client.ms.
//   After changing the code: Deploy > Manage deployments > Edit > Version: New version > Deploy (URL stays).
//
// The hub POSTs JSON: {"type": "login" | "asset" | "button", "value": "<email | card title | button name>"}
// Sheet2 keeps one row per (type, value) with a counter: Type | Value | Count. No dates, no versions.

var STATS_SHEET = 'Sheet2';
var ALLOWED = { login: true, asset: true, button: true };

function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    var d = JSON.parse(e.postData.contents);
    var type = String(d.type || '').toLowerCase();
    if (!ALLOWED[type]) return out_('ignored');
    var value = String(d.value || '').slice(0, 200);
    if (!value) return out_('ignored');
    lock.waitLock(10000);
    count_(sheet_(), type, value, 1);
    return out_('ok');
  } catch (err) {
    return out_('error');
  } finally {
    try { lock.releaseLock(); } catch (x) {}
  }
}

// Adds n to the counter of (type, value), creating the row if needed
function count_(sh, type, value, n) {
  var last = sh.getLastRow();
  if (last > 1) {
    var rows = sh.getRange(2, 1, last - 1, 3).getValues();
    for (var i = 0; i < rows.length; i++) {
      if (rows[i][0] === type && String(rows[i][1]) === value) {
        sh.getRange(i + 2, 3).setValue((Number(rows[i][2]) || 0) + n);
        return;
      }
    }
  }
  sh.appendRow([type, value, n]);
}

function sheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(STATS_SHEET) || ss.insertSheet(STATS_SHEET);
  if (sh.getLastRow() === 0) {
    sh.appendRow(['Type', 'Value', 'Count']);
    sh.setFrozenRows(1);
  }
  return sh;
}

function out_(s) {
  return ContentService.createTextOutput(s).setMimeType(ContentService.MimeType.TEXT);
}

// Run once from the editor after switching to counters: turns the old event rows
// (Time | Type | Value | Hub version) into counters and drops the test rows.
function migrateToCounters() {
  var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(STATS_SHEET);
  if (!sh) return;
  var head = sh.getRange(1, 1, 1, Math.max(sh.getLastColumn(), 1)).getValues()[0];
  if (String(head[0]) !== 'Time') return; // already counters
  var rows = sh.getLastRow() > 1 ? sh.getRange(2, 1, sh.getLastRow() - 1, 4).getValues() : [];
  sh.clear();
  sheet_();
  rows.forEach(function (r) {
    var type = String(r[1]).toLowerCase(), value = String(r[2]), ver = String(r[3]);
    if (ALLOWED[type] && value && ver !== 'test') count_(sh, type, value, 1);
  });
  var summary = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Summary');
  if (summary) SpreadsheetApp.getActiveSpreadsheet().deleteSheet(summary);
}
