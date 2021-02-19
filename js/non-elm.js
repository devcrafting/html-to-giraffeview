var node = document.getElementById('main');
var elm = Elm.HtmlToElmWebsite.Main.init({ node: node});

var globalCurrElmCode = "";

function updateCodeMirrorSize() {
  var leftPanelElement = document.getElementsByClassName("left-panel")[0];
  var width = leftPanelElement.clientWidth;
  var height = leftPanelElement.clientHeight - (30 * 2);
  console.log('new cm height', height);
  codeMirror.setSize(width, height)
}

elm.ports.outgoingElmCode.subscribe(function(currElmCode) {
  console.log("currElmCode:", currElmCode);
  globalCurrElmCode = currElmCode;
  var elmCodeElement = document.getElementById('elm-code');
  elmCodeElement.innerHTML = currElmCode
  hljs.highlightBlock(elmCodeElement);
  updateCodeMirrorSize();
});

var codeMirror;

elm.ports.elmDomReady.subscribe(function() {
  var htmlInputElement = document.getElementById('html');
  console.log(htmlInputElement);
  codeMirror = CodeMirror.fromTextArea(htmlInputElement, {
    mode: "htmlmixed",
    theme: "3024-day"
  });
  codeMirror.focus();
  codeMirror.on('change', function() {
    var currentHtml = codeMirror.getValue();
    console.log('currentHtml changed', currentHtml);
    elm.ports.incomingHtmlCode.send(currentHtml);
  });

  setTimeout(function() {
    updateCodeMirrorSize();
  }, 0)

  var copyButton = document.getElementById('copy-button')
  var zc = new ZeroClipboard(copyButton);
  zc.on( 'ready', function(event) {
    zc.on( 'copy', function(event) {
      event.clipboardData.setData('text/plain', globalCurrElmCode);
      console.log('set zc', globalCurrElmCode);
    } );
  });

  zc.on( 'error', function(event) {
    // console.log( 'ZeroClipboard error of type "' + event.name + '": ' + event.message );
    ZeroClipboard.destroy();
  } );
});


elm.ports.currentSnippet.subscribe(function(currentSnippet) {
  console.log('curr snippet', currentSnippet);
  codeMirror.getDoc().setValue(currentSnippet);
});
