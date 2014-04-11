module Wizards
  # CALLBACKS
  def ping(sender_id, message)
    puts("#{message} from #{sender_id}")
    userlog("#{sender_id}: #{message}")
  end

  def userlog(message)
    puts message
    #DCell::Node["reelweb"][:time_server].async.ping(DCell.me.id.to_s, message)
    true
  end
 
  def wizard_complete(sender_id, response_uuid, response)
    puts("#{response}:#{response_uuid} from #{sender_id}")
    if @agreements[response_uuid]
      callback = @agreements[response_uuid]
      @agreements.reject! { |k,v| k == response_uuid }
      if callback
        callback.call(response)
      else
        puts "no callback found for #{response_uuid}"
      end
    end
    true
  end

  # MENUING VIA BOOTSTRAP

  # yes/no
  # block is used for callback on result
  def agree(message, mainmenu=false, &block)
    menu_uuid = "/gimmegimmegimme#{rand(100000000000)}"
    @agreements[menu_uuid] = block if block_given?
    divid = "anotherranddivid#{rand(1000000)}"
    btndivid = "anotherranddivid#{rand(1000000)}"
    if mainmenu
      topbutton ="<div id=#{btndivid}><a href='##{divid}' role='button' class='btn btn-primary' data-toggle='modal'>#{message}</a></div>"
      showhide = "hide"
    else
# click the wizard tab so that the modal can pop
      topbutton = ""
      showhide = "show"
    end
    html = <<EOF
            #{topbutton}
            <div id="#{divid}" class='modal #{showhide} fade'>
              <div class='modal-header'><h3>#{message}</h3></div>
              <div class='modal-body'>
                <p>#{message}</p>
              </div>
              <div class='modal-footer'>
                    <a id="modal-yes-submit-#{divid}" class='btn btn-primary' href="#">Yes</a>
                    <a id="modal-no-submit-#{divid}" class='btn btn-primary' href="#">No</a>
              </div>
            </div>
            <script type="text/javascript">
              $('##{divid}').modal("#{showhide}")
              $('#modal-no-submit-#{divid}').on('click', function(e){
                // We don't want this to act as a link so cancel the link action
                e.preventDefault();
                var request = $.ajax({
                  url: "#{menu_uuid}",
                  type: "POST",
                  data: {id : "no"},
                  dataType: "html"
                });
                // Hide the modal
                console.log("hiding divid #{divid}");
                $('##{divid}').modal('hide');
                $('##{divid}').html("");
                $('##{btndivid}').html("");
                request.done(function(msg) {
                  console.log("request done");
                });

                request.fail(function(jqXHR, textStatus) {
                  console.log("request fail!");
                });
              });

              $('#modal-yes-submit-#{divid}').on('click', function(e){
                // We don't want this to act as a link so cancel the link action
                e.preventDefault();
                var request = $.ajax({
                  url: "#{menu_uuid}",
                  type: "POST",
                  data: {id : "yes"},
                  dataType: "html"
                });
                // Hide the modal
                console.log("hiding divid #{divid}");
                $('##{divid}').modal('hide');
                $('##{divid}').html("");
                $('##{btndivid}').html("");
                request.done(function(msg) {
                  console.log("request done");
                });

                request.fail(function(jqXHR, textStatus) {
                  console.log("request fail!");
                });
              });
              </script>
EOF
    DCell::Node["reelweb"][:time_server].async.add_wizard(DCell.me.id, html, menu_uuid)
    true
  end

  # show a button menu of choices
  # the_choices ~> Array of Hashes
  # block, callback on selected choice
  def choices(message, the_choices, mainmenu=false, &block)
    menu_uuid = "/gimmegimmegimme#{rand(100000000000)}"
    @agreements[menu_uuid] = block if block_given?
    divid = "anotherranddivid#{rand(1000000)}"
    btndivid = "anotherranddivid#{rand(1000000)}"
    # choices each need a uuid for the div
    choices_with_uuids = {}
    the_choices.each do |choice|
      choices_with_uuids[choice] = "greatchoice#{rand(100000000000)}"
    end
    if mainmenu
      topbutton ="<div id=#{btndivid}><a href='##{divid}' role='button' class='btn btn-primary' data-toggle='modal'>#{message}</a></div>"
      showhide = "hide"
    else
      topbutton = ""
      showhide = "show"
    end

    html_header = <<EOF
            #{topbutton}
            <div id="#{divid}" class='modal #{showhide} fade'>
              <div class='modal-header'><h3>#{message}</h3></div>
              <div class='modal-body'>
EOF
   html_choices = ""
    the_choices.each do |choice|
      choice_uuid = "greatchoice#{rand(100000000000)}"
      new_html =<<EOF 
                <a id="modal-#{choices_with_uuids[choice]}-submit" class='btn btn-primary' href="#">#{choice}</a>
EOF
      html_choices << new_html
    end
    new_html =<<EOF
              </div>
              <div class='modal-footer'>
              </div>
            </div>
            <script type="text/javascript">
              $('##{divid}').modal("#{showhide}")
EOF
    html_choices << new_html
    the_js = ""
    the_choices.each do |choice|
      new_js =<<EOF 
              $('#modal-#{choices_with_uuids[choice]}-submit').on('click', function(e){
                // We don't want this to act as a link so cancel the link action
                e.preventDefault();
                var request = $.ajax({
                  url: "#{menu_uuid}",
                  type: "POST",
                  data: "#{choice}",
                  dataType: "text"
                });
                console.log("hiding divid #{divid}");
                // Hide the modal
                $('##{divid}').modal('hide');
                $('##{divid}').html("");
                $('##{btndivid}').html("");
                request.done(function(msg) {
                  console.log("request done");
                });

                request.fail(function(jqXHR, textStatus) {
                  console.log("request fail!");
                });
              });
EOF
      the_js << new_js
    end
    the_js += "</script>"
    full_html = html_header + html_choices + the_js

    DCell::Node["reelweb"][:time_server].async.add_wizard(DCell.me.id, full_html, menu_uuid)
    true
  end

# TODO: needs work
  def ask(message, mainmenu=false, &block)
    menu_uuid = "/gimmegimmegimme#{rand(100000000000)}"
    @agreements[menu_uuid] = block if block_given?
    divid = "anotherranddivid#{rand(1000000)}"
    btndivid = "anotherranddivid#{rand(1000000)}"
    if mainmenu
      topbutton ="<div id=#{btndivid}><a href='##{divid}' role='button' class='btn btn-primary' data-toggle='modal'>#{message}</a></div>"
      showhide = "hide"
    else
      topbutton = ""
      showhide = "show"
    end
    html = <<EOF
            #{topbutton}
            <div id="#{divid}" class='modal #{showhide} fade'>
              <div class='modal-header'><h3>#{message}</h3></div>
              <div class='modal-body'>
                <p>#{message}</p>
                <input id="myTextBox" type="text" name="answer" value=""/>
              </div>
              <div class='modal-footer'>
                    <a id="modal-submit-#{divid}" class='btn btn-primary' href="#">Submit</a>
              </div>
            </div>
            <script type="text/javascript">
              $('##{divid}').modal("#{showhide}");
              $('#modal-submit-#{divid}').on('click', function(e){
                var datastuff = $('#myTextBox').val();
                // We don't want this to act as a link so cancel the link action
                e.preventDefault();
                var request = $.ajax({
                  url: "#{menu_uuid}",
                  type: "POST",
                  data: datastuff,
                  dataType: "text"
                });
                // Hide the modal
                console.log(datastuff);
                console.log("hiding divid #{divid}");
                $('##{divid}').modal('hide');
                $('##{divid}').html("");
                $('##{btndivid}').html("");
                request.done(function(msg) {
                  console.log("request done");
                });

                request.fail(function(jqXHR, textStatus) {
                  console.log("request fail!");
                });
              });
              </script>
EOF
    DCell::Node["reelweb"][:time_server].async.add_wizard(DCell.me.id, html, menu_uuid)
    true
  end
end
