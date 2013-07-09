# Meteorserver - HTTP Server for realtime Web

Meteor is an open source HTTP server, designed to offer developers a simple means of integrating streaming data into web applications without the need for page refreshes. It aims to offer developers the freedom to think about web development in an entirely new way. It comprises the Meteor server and a standalone Javascript class which can be used in webpages to provide an abstraction layer for receiving data streams. Designed to be as simple and flexible as possible, Meteor offers a great solution for those wishing to add asynchronous functionality to their web projects in the simplest manner possible.

# Why Meteor?

A meteor is the visible event that occurs when a meteoroid or asteroid enters the earth's atmosphere and becomes brightly visible. Meteorserver an implementation of a technique called Comet for using the HTTP protocol for persistent streaming data connections. The term 'Comet' was coined by [Alex Russell](http://alex.dojotoolkit.org/) in his post [Comet: Low Latency Data for the Browser](http://alex.dojotoolkit.org/?p=545).

In fact, this technology has been around for ages, it's just difficult to implement well. Like AJAX before it, 'comet' only really became cool once someone gave it a name and showed the world in simple terms how it works. 

The main problem to be solved is one of scalability - most web servers are not designed to handle requests that take minutes or even hours to complete a response, and their threaded architectures collapse at the first sign of more than a few hundred simultaneously connected clients. As far as Apache is concerned, it's all about getting requests answered and closed as quickly as possible. *That's just not what's needed to make streaming work.*

While [Cometd](https://github.com/cometd/cometd) takes off it's own implementation around [Bayeux Protocol](http://svn.cometd.com/trunk/bayeux/bayeux.html), Meteorserver offers a perl-based HTTP server written from the ground up to support high concurrency and longevity of connections, as well as memory-cached data to allow event-driven broadcasting of the same information to thousands of clients in near-realtime with minimal resource overhead and no disk access.

# Great, but how does it work?

Meteor is two servers in one. It listens on one port for event controllers, and on another for channel subscribers. Event controllers aka *Publishers* are clients that connect on the control port and use Meteor's command protocol to inject events into named channels. Controllers can also issue commands to view the status of channels. Constructing a event controller is as easy as opening a socket and squirting a few simple text-based commands through it, trivial with most web programming platforms.

Subscribers are clients that connect on the subscriber port, and use the standard HTTP protocol to request a subscription to a particular channel or channels. A wide variety of querystring parameters can be included by the subscriber to indicate which interaction mode is desired.

Meteor then [sends the events](http://meteorserver.org/interaction-modes/) provided by the event controllers to the channel subscribers. All events are cached in memory so that the overhead required to send an event to a subscriber is minimal. In this way a few event controllers can do most of the hard work generating and formatting data, but without repetition, while Meteor handles the task of delivering the data to a large audience in near-real time.

Meteor works reliably in your browser *today* by employing several [intelligent techniques](http://meteorserver.org/browser-techniques/). This allows significant advantages to begin using realtime HTTP web today.

# Installation

View the [installation instructions](INSTALL.md) to get started.

# FAQ

View current [FAQ](http://meteorserver.org/faq/).

# Future

Meteor is moving over from previous [Google Repo](http://code.google.com/p/meteorserver/) onto Github, and will continue  to be maintained, supported here.
