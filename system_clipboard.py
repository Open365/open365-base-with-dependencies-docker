#!/usr/bin/python3
import sys
from PyQt5.QtGui import QGuiApplication, QClipboard

if __name__ == '__main__':

    app = QGuiApplication(sys.argv)

    clipboard = QGuiApplication.clipboard()
    def dataChanged():
        copiedText = clipboard.text(QClipboard.Clipboard)
        if copiedText:
            print("copiedText:" + copiedText)
            sys.stdout.flush()

    def selectionChanged():
        selectedText = clipboard.text(QClipboard.Selection)
        if selectedText:
            print("selectedText:" + selectedText)
            sys.stdout.flush()

    clipboard.dataChanged.connect(dataChanged)
    clipboard.selectionChanged.connect(selectionChanged)

    sys.exit(app.exec_())
