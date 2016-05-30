#!/usr/bin/python3

import uno;
import time;
import os;
import sys;
import threading
from PyQt5.QtCore import pyqtSlot
from PyQt5.QtGui import QGuiApplication, QClipboard

def getSelectedTextWriter(desktop):
    # Get LibreOffice Doc from DESKTOP
    doc = desktop.getCurrentComponent();
    controller = doc.getCurrentController();
    indexAccess = controller.getSelection();
    textRange = indexAccess.getByIndex(0);
    selectedText = textRange.getString();
    if selectedText:
        return selectedText

def getSelectedTextCalc(desktop):
    # Get LibreOffice Doc from DESKTOP
    doc = desktop.getCurrentComponent();
    controller = doc.getCurrentController();
    indexAccess = controller.getSelection();
    data = indexAccess.getDataArray()
    data = '\n'.join('\t'.join(arr) for arr in data)
    if data:
        return str(data)


getSelectedTextFuncs = {
    'writer': getSelectedTextWriter,
    'calc': getSelectedTextCalc
}

def getSelectedText():
    connected = False
    while not connected:
        try:
            # Establish a connection with the LO API Service
            localContext = uno.getComponentContext();
            resolver = localContext.ServiceManager.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", localContext);
            ctx = resolver.resolve("uno:pipe,name=open365_LO;urp;StarOffice.ComponentContext");
            smgr = ctx.ServiceManager;
            connected = True;
        except Exception:
            time.sleep(0.5);

    desktop = smgr.createInstanceWithContext("com.sun.star.frame.Desktop", ctx);
    getSelectedTextFunc = getSelectedTextFuncs[sys.argv[1]]
    return getSelectedTextFunc(desktop)

lock = threading.Lock()

def textCopied():
    with lock:
        print("copiedText:" + getSelectedText());
        sys.stdout.flush();

def selectingText():
    previousSelectedText = None;
    currentSelectedText = None;
    while True:
        currentSelectedText = getSelectedText();
        if currentSelectedText and currentSelectedText != previousSelectedText:
            with lock:
                print("selectedText:" + currentSelectedText);
                sys.stdout.flush();
            previousSelectedText = currentSelectedText;

        time.sleep(0.05);

t = threading.Thread(target=selectingText);
t.daemon = True;
t.start();

app = QGuiApplication(sys.argv);
clipboard = QGuiApplication.clipboard()
clipboard.dataChanged.connect(textCopied)
sys.exit(app.exec_())
