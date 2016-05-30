/*
    Copyright (c) 2016 eyeOS

    This file is part of Open365.

    Open365 is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

var shell = require('child_process');
var userNotification = require('eyeos-usernotification');
var NotificationController = userNotification.NotificationController;
var Notification = userNotification.Notification;
var notificationController = new NotificationController();

var command = '/root/run.sh';
var args = process.argv.slice(2);

var proc = shell.spawn(command, args, {detached: true});
var reconnectWaitingTime = process.env.RECONNECT_WAITING_TIME || 5000;
var closeAppWaitingTime = process.env.CLOSE_APP_WAITING_TIME || 5000;
var application = process.argv[2];
var timer = 0;
var username = process.env['EYEOS_USER'] + '@' + process.env['EYEOS_DOMAIN'];
var token = process.env['EYEOS_TOKEN'];

var uid = parseInt(process.env['SPICE_UID'], 10);
var gid = parseInt(process.env['SPICE_GID'], 10);

var libreoffice_scripts_settings = {
    detached: true,
    stdio: ["ignore", process.stdout, process.stderr],
    uid: isNaN(uid) ? 1000 : uid,
    gid: isNaN(gid) ? 1000 : gid
};

timer = setTimeout(function() {
    doShutdown();
}, 60000);

var waitUtilDisconnect = function(data) {

    var output = data.toString('utf-8');
    console.log(output);
    var clientConnected = 'add main channel client'; /*main_channel_link: add main channel client*/
    var clientDisconnected = 'main_channel_client_on_disconnect';   /* main_channel_client_on_disconnect: rcc=0x562cead91100*/
    var clientReady = 'spice-vdagentd: opening vdagent virtio channel';

    if (output.indexOf(clientReady) > -1) {
        // process client ready
        console.log('READY!');
        sendReadyMessage();
    }

    if (output.indexOf(clientConnected) > -1) {
        // process client connected
        console.log('Client connected! :)');
        if (timer) {
            console.log('Timer exists');
            clearTimeout(timer);
            timer = 0;
        }
    } else if (output.indexOf(clientDisconnected) > -1) {
        // process client disconnect
        console.log('Client disconnected! :(');
        shell.spawn("save.py", [], libreoffice_scripts_settings);
        timer = setTimeout(function() {
            doShutdown();
        }, reconnectWaitingTime);
    }
};

proc.stdout.on('data', waitUtilDisconnect);

proc.stderr.on('data', waitUtilDisconnect);

proc.on('close', function(code){
    
});

var officeApps = [
    'writer',
    'calc',
    'presentation'
];

var sendReadyMessage = function() {
    var type = 'readyMessage';
    var useUserExchange = true;
    var body = {
        "username": username,
        "token": token
    };

    var notification = new Notification(type, body);

    notificationController.notifyUser(notification, username, useUserExchange, false, function(err) {
        if (err) {
            console.error(err);
        }
        console.log('Succesfully sended ' + type);
    });
};

var doShutdown = function(){

    var shutdownCommand;
    switch (application) {
        case 'writer':
        case 'presentation':
        case 'calc':
            shutdownCommand = '/usr/bin/closeApps.sh';
            break;
        case 'mail':
            shutdownCommand = 'pkill thunderbird';
            break;
        default:
            shutdownCommand = '';
    }

    console.log('Running:', shutdownCommand);
    shell.exec(shutdownCommand, function() {
        console.log('Application stopped');
        console.log('Exiting because app has been closed!');
        process.exit(0);
    });

    setTimeout(function() {
        console.log('OPS! App not closed, but exiting anyway!');

        if (officeApps.indexOf(application) >= 0) {
            killOffice();
        } else {
            process.exit(0);
        }

    }, closeAppWaitingTime);
};

var killOffice = function() {
    console.log('Killing libreoffice abruptly');

    var shutdownCommand = 'find /home/user -name ".~lock*" -exec rm {} \\; && pkill soffice';
    shell.exec(shutdownCommand, function() {
        console.log('.~lock file removed', arguments);
        console.log('Libreoffice killed');
        process.exit(0);
    });

    setTimeout(function() {
        console.log('Poor LibreOffice...');
        process.exit(0);

    }, closeAppWaitingTime);
};

if (process.env['ENABLE_LIBREOFFICE_AUTOSAVE']  === 'true' &&
    officeApps.indexOf(application) !== -1) {
    shell.spawn("autosave.py", [], libreoffice_scripts_settings);
}
