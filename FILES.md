# File Description

Meteorserver is made of a Perl server implementation, and a set of Javascript files for use on client side.

    Meteor/ - Meteor's perl modules
        Channel.pm - A Meteor channel
        Config.pm - Meteor configuration handling
        Connection.pm - Common super-class for controller and subscriber
        Controller.pm - A Meteor controller
        Document.pm - Caching and serving mechansim for static documents
        Message.pm - Meteor message object
        Socket.pm - Meteor Socket additions
        Subscriber.pm - A Meteor subscriber
        Syslog.pm - Convenience interface to Sys::Syslog
    public_html/ - document root for static page serving
        poll.html - JavaScript IFRAME source for polling connections
        stream.html - JavaScript IFRAME source for streaming connections
        meteor.js - JavaScript class required for Meteor web browser client
    meteord - The Meteor executable
    meteor.conf.dist - Sample configuration file
    daemoncontroller.dist - Meteor deamon init script shell script
