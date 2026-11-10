// Physicl Hub Browser - usage statistics receiver (Google Apps Script, bound to the releases spreadsheet).
// Deploy: Extensions > Apps Script > paste this file > Deploy > New deployment > Web app,
//   Execute as: Me, Who has access: Anyone. The Web app URL is statsUrl in PHB_Client.ms.
//   After changing the code: Deploy > Manage deployments > Edit > Version: New version > Deploy (URL stays).
//
// The hub POSTs JSON: {"type": "login" | "asset" | "button", "value": "<email | card title | button name>"}
// Sheet2 layout (row 1 = headers, user's design 2026-11-10):
//   A: users (each email once)   B: button  C: count   D: asset  E: count

var STATS_SHEET = 'Sheet2';
var COLS = { login: [1, 0], button: [2, 3], asset: [4, 5] }; // [value column, count column (0 = none)]

function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    var d = JSON.parse(e.postData.contents);
    var type = String(d.type || '').toLowerCase();
    var c = COLS[type];
    var value = String(d.value || '').slice(0, 200);
    if (!c || !value) return out_('ignored');
    lock.waitLock(10000);
    bump_(sheet_(), c[0], c[1], value);
    return out_('ok');
  } catch (err) {
    return out_('error');
  } finally {
    try { lock.releaseLock(); } catch (x) {}
  }
}

// Finds value in column vc (rows 2..); adds 1 to its count in column cc, or writes it in the
// first empty row of that column with count 1. cc = 0: just keep the value once (users).
function bump_(sh, vc, cc, value) {
  var last = Math.max(sh.getLastRow(), 1);
  var vals = last > 1 ? sh.getRange(2, vc, last - 1, 1).getValues() : [];
  var empty = -1;
  for (var i = 0; i < vals.length; i++) {
    var v = String(vals[i][0]);
    if (v === value) {
      if (cc) {
        var cell = sh.getRange(i + 2, cc);
        cell.setValue((Number(cell.getValue()) || 0) + 1);
      }
      return;
    }
    if (v === '' && empty < 0) empty = i;
  }
  var row = empty >= 0 ? empty + 2 : last + 1;
  sh.getRange(row, vc).setValue(value);
  if (cc) sh.getRange(row, cc).setValue(1);
}

function sheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(STATS_SHEET) || ss.insertSheet(STATS_SHEET);
  if (sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, 5).setValues([['users', 'button', 'count', 'asset', 'count']]);
    sh.setFrozenRows(1);
  }
  return sh;
}

function out_(s) {
  return ContentService.createTextOutput(s).setMimeType(ContentService.MimeType.TEXT);
}
