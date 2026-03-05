import Foundation

struct EditorTemplateProvider {
    func html() -> String {
        if let url = Bundle.main.url(forResource: "editor", withExtension: "html"),
           let html = try? String(contentsOf: url) {
            return html
        }

        return fallbackHTML
    }

    private var fallbackHTML: String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset=\"utf-8\" />
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
          <meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src 'self' 'unsafe-inline' file:; style-src 'self' 'unsafe-inline' file:; img-src data: file:;\" />
          <link rel=\"stylesheet\" href=\"vendor/codemirror/lib/codemirror.min.css\" />
          <script src=\"vendor/codemirror/lib/codemirror.min.js\"></script>
          <script src=\"vendor/codemirror/mode/xml/xml.min.js\"></script>
          <script src=\"vendor/codemirror/mode/meta.min.js\"></script>
          <script src=\"vendor/codemirror/mode/markdown/markdown.min.js\"></script>
          <style>
            html, body { height: 100%; margin: 0; }
            .CodeMirror { height: 100vh; font-size: 14px; font-family: Menlo, monospace; }
          </style>
        </head>
        <body>
          <textarea id=\"editor\"></textarea>
          <script>
            const editor = CodeMirror.fromTextArea(document.getElementById('editor'), {
              mode: 'markdown',
              lineNumbers: true,
              lineWrapping: true,
              undoDepth: 10000
            });

            window.setContent = function(value) {
              if (editor.getValue() !== value) {
                editor.setValue(value);
              }
            };

            editor.on('change', function() {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.textDidChange) {
                window.webkit.messageHandlers.textDidChange.postMessage(editor.getValue());
              }
            });
          </script>
        </body>
        </html>
        """
    }
}
