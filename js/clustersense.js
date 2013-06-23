
// simpleSockets block ?
var SocketKlass = "MozWebSocket" in window ? MozWebSocket : WebSocket;
var ws = new SocketKlass('ws://' + window.location.host + '/timeinfo');

var canvas = document.getElementById('cells');
var ctx = canvas.getContext("2d");
var counter = 150;
var x = 0;
var y = 0;
var xx = 0;
var yy = 0;
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

var tuximg = new Image();
tuximg.src = "/sprites/liltux.png";

function drawTux(tx, ty) {
  ctx.drawImage(tuximg, tx, ty)
}

function drawText(text, dx, dy) {
  ctx.fillStyle = "rgb(200,200,200)";
  ctx.font = "12pt Helvetica";
  ctx.fillText(text, dx, dy);
}

function clearText(text, dx, dy) {
  ctx.fillStyle = "rgb(200,200,200)";
  ctx.font = "12pt Helvetica";
  ctx.fillText(text, dx, dy);
}

function roundRect(sx,sy,ex,ey,r) {
    var r2d = Math.PI/180;
    if( ( ex - sx ) - ( 2 * r ) < 0 ) { r = ( ( ex - sx ) / 2 ); } //ensure that the radius isn't too large for x
    if( ( ey - sy ) - ( 2 * r ) < 0 ) { r = ( ( ey - sy ) / 2 ); } //ensure that the radius isn't too large for y
    ctx.beginPath();
    ctx.moveTo(sx+r,sy);
    ctx.lineTo(ex-r,sy);
    ctx.arc(ex-r,sy+r,r,r2d*270,r2d*360,false);
    ctx.lineTo(ex,ey-r);
    ctx.arc(ex-r,ey-r,r,r2d*0,r2d*90,false);
    ctx.lineTo(sx+r,ey);
    ctx.arc(sx+r,ey-r,r,r2d*90,r2d*180,false);
    ctx.lineTo(sx,sy+r);
    ctx.arc(sx+r,sy+r,r,r2d*180,r2d*270,false);
    ctx.closePath();
    ctx.stroke();
    ctx.fill();
}

function animate() {
  if(updown == 0) {
    counter++; 
  }
  else {
    counter--;
  }
  if(counter > 200) { updown = 1 }
  if(counter < 150) { updown = 0 }
  ctx.fillStyle = "rgb(0," + counter + ",0)";
  //ctx.fillStyle = "rgb(0,100,0)";
  ctx.strokeStyle = "#0f0";
  for(var i = 0; i < nodes.length; i++) {
    if(selected[i] == true) {
      ctx.fillStyle = "rgb(180,0,200)";
    }
    else if(nodes[i]["state"] == "connected") {
      ctx.fillStyle = "rgb(0," + counter + ",0)";
    }
    else {
      ctx.fillStyle = "rgb(200,0,0)";
    }
    x = nodes[i]["x"];
    y = nodes[i]["y"];
    xx = nodes[i]["xx"];
    yy = nodes[i]["yy"];
    roundRect(x,y,xx,yy,5);
    drawTux((x-50),y);
    drawText(nodes[i]["id"], x, y);
  }
  // just clear out the messages pane
  //ctx.clearRect(500, y+200, canvas.width, (y+200+(12*128)));
  // draw the messages
  //for(var k = 0; k < messages.length; k++) {
  //  drawText(messages[k], 500, (200+y+(k*20)));
  //}
// just clear out the payloads pane
  //ctx.clearRect(10, 200, canvas.width, (y+(12*50)));
  //for(var c = 0; c < payloads.length; c++) {
  //  drawText(payloads[c], 10, (200+y+(c*20)));
  //}
}

function hilight(xcoord,ycoord) {
  var foundx = false;
  var foundy = false;
  xcoord = xcoord - 480;
  ycoord = ycoord - 435;
  for(var i = 0; i < nodes.length; i++) {
    if((xcoord >= nodes[i]["x"]) && (xcoord <= nodes[i]["xx"])) { foundx = true; }
    if((ycoord >= nodes[i]["x"]) && (ycoord <= nodes[i]["yy"])) { foundy = true; }   
    if(foundx && foundy && selected[i] == true) {
      selected[i] = false;
      console.log(foundx,foundy);
      return true;
    } else if(foundx && foundy) {
      selected[i] = true;
      console.log(foundx,foundy);
      return true;
    } 
  }
}

canvas.addEventListener('mousedown', function(e) {
  var mx = e.pageX;
  var my = e.pageY;
  console.log(mx, my);
  hilight(mx, my);
})

ws.onmessage = function(msg){
  world_hash = JSON.parse(msg.data);
  nodes = world_hash["nodes"];
  old_messages = messages;
  messages = world_hash["messages"];
  payloads = world_hash["payloads"];
  if(world_hash["messages"]) {
    //$("#logs").html("<code>" + world_hash["messages"].join("<br>"));
    $("#logs").html("<code>" + world_hash["messages"].join("<br>") + "</code>");
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

  // stop the previous animations
  for(var j = 0; j < animations.length; j++) {
    var kill_this = animations.pop();
    clearInterval(kill_this);
  }
  // clear the drawing board
  // kinda slow and flickery to clear the whole board..
  //ctx.clearRect(0, 0, canvas.width, canvas.height);
  // start new animations
  for(var i = 0; i < nodes.length; i++) {
    // store the animation ids
    animations.push(setInterval(animate, 50));
  }
}
