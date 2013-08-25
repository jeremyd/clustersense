
// simpleSockets block ?
var SocketKlass = "MozWebSocket" in window ? MozWebSocket : WebSocket;
var ws = new SocketKlass('ws://' + window.location.host + '/timeinfo');

var world_hash = {};
var nodes = []
var animations = [];
var messages = [];
var payloads = [];
var old_messages = [];
var selected = [];
var wizards = [];
var old_wizards = {};
var updown = 0;
var counter = 0;

var tuximg = new Image();
tuximg.src = "/sprites/liltux.png";

function animate() {
  if(updown == 0) {
    counter = counter + 10; 
  }
  else {
    counter = counter - 10;
  }
  if(counter > 200) { updown = 1 }
  if(counter < 150) { updown = 0 }
  $("#git").html("");
  $("#git").append("<p><b>Sensing " + nodes.length + " nodes</b></p>");
  for(var i = 0; i < nodes.length; i++) {
    $("#git").append("<p>" + nodes[i]["id"] + "</a>");
  }
}

ws.onmessage = function(msg){
  world_hash = JSON.parse(msg.data);
  nodes = world_hash["nodes"];
  old_messages = messages;
  messages = world_hash["messages"];
  payloads = world_hash["payloads"];
  if(world_hash["messages"]) {
    //$("#logs").html("<code>" + world_hash["messages"].join("<br>"));
    $("#logs").html("<p>" + world_hash["messages"].join("<br>") + "</p>");
  }
  if(world_hash["wizards"]) {
    //console.log("num wizards: " + world_hash["wizards"].length);
    //console.log("old wizards: ");
    //console.log($.map(old_wizards, function(v,k) { return k; }));

    $.each( world_hash["wizards"], function( index, wiz ) {
    //  console.log(index);
    //  console.log(wiz["response_uuid"]);
      if(old_wizards[wiz["response_uuid"]] != null) {
        //old wizard says we've already rendered this wizard
    //    console.log("already rendered this wizard!");
      } else {
    //    console.log("adding a wizard to the page");
        old_wizards[wiz["response_uuid"]] = true;
        $("#wizard").append(wiz["html"]);
      }
    });
    //$("#wizard").html("");
  }
  animate();
}
