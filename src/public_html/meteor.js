/*
stream: xhrinteractive, iframe, serversent
longpoll
smartpoll
simplepoll
*/

Meteor = {

	callbacks: {
		process: function() {},
		reset: function() {},
		eof: function() {},
		statuschanged: function() {},
		changemode: function() {}
	},
	channelcount: 0,
	channels: {},
	debugmode: false,
	frameref: null,
	host: null,
	hostid: null,
	maxpollfreq: 60000,
	minpollfreq: 2000,
	mode: "stream",
	pingtimeout: 20000,
	pingtimer: null,
	pollfreq: 3000,
	port: 80,
	polltimeout: 30000,
	recvtimes: [],
	status: 0,
	updatepollfreqtimer: null,

	register: function(ifr) {
		ifr.p = Meteor.process;
		ifr.r = Meteor.reset;
		ifr.eof = Meteor.eof;
		ifr.ch = Meteor.channelInfo;
		clearTimeout(Meteor.frameloadtimer);
		Meteor.setstatus(4);
		Meteor.log("Frame registered");
	},

	joinChannel: function(channelname, backtrack) {
		if (typeof(Meteor.channels[channelname]) != "undefined") throw "Cannot join channel "+channelname+": already subscribed";
		Meteor.channels[channelname] = {backtrack:backtrack, lastmsgreceived:0};
		Meteor.log("Joined channel "+channelname);
		Meteor.channelcount++;
		if (Meteor.status != 0) Meteor.connect();
	},

	leaveChannel: function(channelname) {
		if (typeof(Meteor.channels[channelname]) == "undefined") throw "Cannot leave channel "+channelname+": not subscribed";
		delete Meteor.channels[channelname];
		Meteor.log("Left channel "+channelname);
		if (Meteor.status != 0) Meteor.connect();
		Meteor.channelcount--;
	},

	connect: function() {
		Meteor.log("Connecting");
		if (!Meteor.host) throw "Meteor host not specified";
		if (isNaN(Meteor.port)) throw "Meteor port not specified";
		if (!Meteor.channelcount) throw "No channels specified";
		if (Meteor.status) Meteor.disconnect();
		Meteor.setstatus(1);
		var now = new Date();
		var t = now.getTime();
		if (!Meteor.hostid) Meteor.hostid = t+""+Math.floor(Math.random()*1000000)
		document.domain = Meteor.extract_xss_domain(document.domain);
		if (Meteor.mode=="stream") Meteor.mode = Meteor.selectStreamTransport();
		Meteor.log("Selected "+Meteor.mode+" transport");
		if (Meteor.mode=="xhrinteractive" || Meteor.mode=="iframe" || Meteor.mode=="serversent") {
			if (Meteor.mode == "iframe") {
				Meteor.loadFrame(Meteor.getSubsUrl());
			} else {
				Meteor.loadFrame("http://"+Meteor.host+((Meteor.port==80)?"":":"+Meteor.port)+"/stream.html");
			}
			clearTimeout(Meteor.pingtimer);
			Meteor.pingtimer = setTimeout(Meteor.pollmode, Meteor.pingtimeout);

		} else {
			Meteor.loadFrame("http://"+Meteor.host+((Meteor.port==80)?"":":"+Meteor.port)+"/poll.html");
			Meteor.recvtimes[0] = t;
			if (Meteor.updatepollfreqtimer) clearTimeout(Meteor.updatepollfreqtimer);
			if (Meteor.mode=='smartpoll') Meteor.updatepollfreqtimer = setInterval(Meteor.updatepollfreq, 2500);
			if (Meteor.mode=='longpoll') Meteor.pollfreq = Meteor.minpollfreq;
		}
		Meteor.lastrequest = t;
	},

	disconnect: function() {
		if (Meteor.status) {
			clearTimeout(Meteor.pingtimer);
			clearTimeout(Meteor.updatepollfreqtimer);
			clearTimeout(Meteor.frameloadtimer);
			if (typeof CollectGarbage == 'function') CollectGarbage();
			if (Meteor.status != 6) Meteor.setstatus(0);
			Meteor.log("Disconnected");
		}
	},
	
	selectStreamTransport: function() {
		try {
			var test = ActiveXObject;
			return "iframe";
		} catch (e) {}
		if ((typeof window.addEventStream) == "function") return "iframe";
		return "xhrinteractive";
	},

	getSubsUrl: function() {
		var surl = "http://" + Meteor.host + ((Meteor.port==80)?"":":"+Meteor.port) + "/push/" + Meteor.hostid + "/" + Meteor.mode;
		for (var c in Meteor.channels) {
			surl += "/"+c;
			if (Meteor.channels[c].lastmsgreceived > 0) {
				surl += ".r"+(Meteor.channels[c].lastmsgreceived+1);
			} else if (Meteor.channels[c].backtrack > 0) {
				surl += ".b"+Meteor.channels[c].backtrack;
			} else if (Meteor.channels[c].backtrack < 0 || isNaN(Meteor.channels[c].backtrack)) {
				surl += ".h";
			}
		}
		var now = new Date();
		surl += "?nc="+now.getTime();
		return surl;
	},

	loadFrame: function(url) {
		try {
			if (!Meteor.frameref) {
				var transferDoc = new ActiveXObject("htmlfile");
				Meteor.frameref = transferDoc;
			}
			Meteor.frameref.open();
			Meteor.frameref.write("<html><script>");
			Meteor.frameref.write("document.domain=\""+(document.domain)+"\";");
			Meteor.frameref.write("</"+"script></html>");
			Meteor.frameref.parentWindow.Meteor = Meteor;
			Meteor.frameref.close();
			var ifrDiv = Meteor.frameref.createElement("div");
			Meteor.frameref.appendChild(ifrDiv);
			ifrDiv.innerHTML = "<iframe src=\""+url+"\"></iframe>";
		} catch (e) {
			if (!Meteor.frameref) {
				var ifr = document.createElement("IFRAME");
				ifr.style.width = "10px";
				ifr.style.height = "10px";
				ifr.style.border = "none";
				ifr.style.position = "absolute";
				ifr.style.top = "-10px";
				ifr.style.marginTop = "-10px";
				ifr.style.zIndex = "-20";
				ifr.Meteor = Meteor;
				document.body.appendChild(ifr);
				Meteor.frameref = ifr;
			}
			Meteor.frameref.setAttribute("src", url);
		}
		Meteor.log("Loading URL '"+url+"' into frame...");
		Meteor.frameloadtimer = setTimeout(Meteor.frameloadtimeout, 5000);
	},

	pollmode: function() {
		Meteor.log("Ping timeout");
		Meteor.mode="smartpoll";
		clearTimeout(Meteor.pingtimer);
		Meteor.callbacks["changemode"]("poll");
		Meteor.lastpingtime = false;
		Meteor.connect();
	},

	process: function(id, channel, data) {
		if (id == -1) {
			Meteor.log("Ping");
			Meteor.ping();
		} else if (typeof(Meteor.channels[channel]) != "undefined") {
			Meteor.log("Message "+id+" received on channel "+channel+" (last id on channel: "+Meteor.channels[channel].lastmsgreceived+")\n"+data);
			Meteor.callbacks["process"](data);
			Meteor.channels[channel].lastmsgreceived = id;
			if (Meteor.mode=="smartpoll") {
				var now = new Date();
				Meteor.recvtimes[Meteor.recvtimes.length] = now.getTime();
				while (Meteor.recvtimes.length > 5) Meteor.recvtimes.shift();
			}
		}
		Meteor.setstatus(5);
	},

	ping: function() {
		if (Meteor.pingtimer) {
			clearTimeout(Meteor.pingtimer);
			Meteor.pingtimer = setTimeout(Meteor.pollmode, Meteor.pingtimeout);
			var now = new Date();
			Meteor.lastpingtime = now.getTime();
		}
		Meteor.setstatus(5);
	},

	reset: function() {
		if (Meteor.status != 6) {
			Meteor.log("Stream reset");
			Meteor.ping();
			Meteor.callbacks["reset"]();
			var now = new Date();
			var t = now.getTime();
			var x = Meteor.pollfreq - (t-Meteor.lastrequest);
			if (x < 10) x = 10;
			setTimeout(Meteor.connect, x);
		}
	},

	eof: function() {
		Meteor.log("Received end of stream, will not reconnect");
		Meteor.callbacks["eof"]();
		Meteor.setstatus(6);
		Meteor.disconnect();
	},

	channelInfo: function(channel, id) {
		Meteor.channels[channel].lastmsgreceived = id;
		Meteor.log("Received channel info for channel "+channel+": resume from "+id);
	},

	updatepollfreq: function() {
		var now = new Date();
		var t = now.getTime();
		var avg = 0;
		for (var i=1; i<Meteor.recvtimes.length; i++) {
			avg += (Meteor.recvtimes[i]-Meteor.recvtimes[i-1]);
		}
		avg += (t-Meteor.recvtimes[Meteor.recvtimes.length-1]);
		avg /= Meteor.recvtimes.length;
		var target = avg/2;
		if (target < Meteor.pollfreq && Meteor.pollfreq > Meteor.minpollfreq) Meteor.pollfreq = Math.ceil(Meteor.pollfreq*0.9);
		if (target > Meteor.pollfreq && Meteor.pollfreq < Meteor.maxpollfreq) Meteor.pollfreq = Math.floor(Meteor.pollfreq*1.05);
	},

	registerEventCallback: function(evt, funcRef) {
		Function.prototype.andThen=function(g) {
			var f=this;
			var a=Meteor.arguments
			return function(args) {
				f(a);g(args);
			}
		};
		if (typeof Meteor.callbacks[evt] == "function") {
			Meteor.callbacks[evt] = (Meteor.callbacks[evt]).andThen(funcRef);
		} else {
			Meteor.callbacks[evt] = funcRef;
		}
	},

	frameloadtimeout: function() {
		Meteor.log("Frame load timeout");
		if (Meteor.frameloadtimer) clearTimeout(Meteor.frameloadtimer);
		Meteor.setstatus(3);
		Meteor.pollmode();
	},

	extract_xss_domain: function(old_domain) {
		if (old_domain.match(/^(\d{1,3}\.){3}\d{1,3}$/)) return old_domain;
		domain_pieces = old_domain.split('.');
		return domain_pieces.slice(-2, domain_pieces.length).join(".");
	},

	setstatus: function(newstatus) {
		// Statuses:	0 = Uninitialised,
		//				1 = Loading stream,
		//				2 = Loading controller frame,
		//				3 = Controller frame timeout, retrying.
		//				4 = Controller frame loaded and ready
		//				5 = Receiving data
		//				6 = End of stream, will not reconnect

		if (Meteor.status != newstatus) {
			Meteor.status = newstatus;
			Meteor.callbacks["statuschanged"](newstatus);
		}
	},

	log: function(logstr) {
		if (Meteor.debugmode) {
			if (window.console) {
				window.console.log(logstr);
			} else if (document.getElementById("meteorlogoutput")) {
				document.getElementById("meteorlogoutput").innerHTML += logstr+"<br/>";
			}
		}
	}
}

var oldonunload = window.onunload;
if (typeof window.onunload != 'function') {
	window.onunload = Meteor.disconnect;
} else {
	window.onunload = function() {
		if (oldonunload) oldonunload();
		Meteor.disconnect();
	}
}