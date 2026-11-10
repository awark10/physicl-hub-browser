// Physicl Hub Browser - usage statistics receiver (Google Apps Script, bound to the stats spreadsheet).
// Deploy: Extensions > Apps Script > paste this file > Deploy > New deployment > Web app,
//   Execute as: Me, Who has access: Anyone. Copy the Web app URL into PHB_Client.ms (statsUrl).
//
// The hub POSTs JSON: {"type": "login" | "asset" | "button", "value": "<email | card title | button name>", "version": "1.2.x"}
// Every event becomes one row on the "Events" sheet; the "Summary" sheet counts them with formulas.

var EVENTS_SHEET = 'Sheet2'; // events sheet in the releases spreadsheet (user's choice, 2026-11-10)
var ALLOWED = { login: true, asset: true, button: true };

function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    var d = JSON.parse(e.postData.contents);
    var type = String(d.type || '').toLowerCase();
    if (!ALLOWED[type]) return out_('ignored');
    var value = String(d.value || '').slice(0, 200);
    var version = String(d.version || '').slice(0, 20);
    lock.waitLock(10000);
    var sh = sheet_();
    sh.appendRow([new Date(), type, value, version]);
    return out_('ok');
  } catch (err) {
    return out_('error');
  } finally {
    try { lock.releaseLock(); } catch (x) {}
  }
}

function sheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(EVENTS_SHEET);
  if (!sh) sh = ss.insertSheet(EVENTS_SHEET);
  if (sh.getLastRow() === 0) {
    sh.appendRow(['Time', 'Type', 'Value', 'Hub version']);
    sh.setFrozenRows(1);
  }
  return sh;
}

function out_(s) {
  return ContentService.createTextOutput(s).setMimeType(ContentService.MimeType.TEXT);
}

// Run once from the editor to create the Events and Summary sheets.
function setup() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  sheet_();
  var sm = ss.getSheetByName('Summary') || ss.insertSheet('Summary');
  sm.clear();
  sm.getRange('A1').setValue('Users (logins per email)');
  sm.getRange('A2').setFormula("=QUERY(Sheet2!A:D,\"select C, count(A), max(A) where B = 'login' group by C order by count(A) desc label C 'Email', count(A) 'Logins', max(A) 'Last login'\",1)");
  sm.getRange('E1').setValue('Assets (imports per card)');
  sm.getRange('E2').setFormula("=QUERY(Sheet2!A:D,\"select C, count(A) where B = 'asset' group by C order by count(A) desc label C 'Card', count(A) 'Imports'\",1)");
  sm.getRange('H1').setValue('Buttons (clicks)');
  sm.getRange('H2').setFormula("=QUERY(Sheet2!A:D,\"select C, count(A) where B = 'button' group by C order by count(A) desc label C 'Button', count(A) 'Clicks'\",1)");
  sm.getRange('K1').setValue('Unique users');
  sm.getRange('K2').setFormula("=COUNTUNIQUE(FILTER(Sheet2!C:C, Sheet2!B:B=\"login\"))");
}
