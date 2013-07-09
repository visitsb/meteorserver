# Install

Meteor installation is very simple. Please follow below instructions to get Meteor working on your Windows, or Linux webserver environment. Meteor consists of [a set of Perl and Javascript files](FILES.md), hence at minimum your webserver environment should have below prerequisites available.

# Prerequisites

A Windows, or *nix webserver environment with latest version of Perl installed.

1. A Windows webserver environment with a [Perl variant for Windows](http://www.perl.org/get.html#win32) installed. We recommend [ActiveState Perl](http://www.activestate.com/activeperl) since it includes few packages pre-bundled. We haven't tried other variants under Windows, but if you do please drop a comment and we'll take a look.
2. A *nix webserver environment with latest version of perl installed.

# Installation

1. Download [latest version](build/meteor-latest.tgz), unzip and setup meteor.
2. Add meteor.js to your page
3. Register an event callback in your page via Javascript

# Setup Meteor

After you have extracted the latest build, you should have all [required files](FILES.md) extracted to get started. 

1. Create a configuration file *meteor.conf* in the extracted folder. For convenience, we have provided a configuration file *meteor.conf.dist* that you can simply rename to *meteor.conf*, and use.
2. You need to start the Meteor server by running below command-

        {path to perl executable} ./meteord -d

   ./meteord is the startup file that loads necessary Perl modules, and starts an HTTP server on default port 4670 as specified in meteor.conf. You can specify additional options as described [here](http://meteorserver.org/server-docs/). 
3. Check if you can access Javascript files from Meteor in your browser

        http://127.0.01:4670/meteor.js

4. Create a test html page on your webserver that refers to meteor.js from above path. The script exposes a single variable Meteor that you use to setup [client side options](http://meteorserver.org/client-docs/).
   
        <head>
            <!-- Refer to meteor.js from your Meteor server -->
            <script type="text/javascript" src="http://data.example.com/meteor.js"></script>
        </head>

        // Initialize our client to listen a channel, perhaps inside a $(document).ready() event
        Meteor.hostid = $.now();    //    Set this to something unique to this client, for eg. [jQuery's now()](http://api.jquery.com/jQuery.now/)
        Meteor.host = "data."+location.hostname;    // Our Meteor server is on the data. subdomain. Use the same hostname from where meteor.js is served.
        Meteor.registerEventCallback("process", test);    // Call the local test() function when data arrives
        Meteor.joinChannel("demo", 5);    // Join the demo channel and get last five events
        Meteor.mode = 'stream';    // , then stream
        Meteor.connect();    // Start streaming!
        function test(data) {    // Handle incoming events
            window.status = data;
        };

That's it! You are setup to communicate in realtime with your clients. You can push messages from server to a channel, and any subscribers listening on the channel will receive those messages.

You can view detailed installation instructions, including how to setup Meteor, and your webserver on same domain [here](http://meteorserver.org/installation/).
