#part-handler

def list_types():
    # return a list of mime-types that are handled by this module
    return(["text/openvpn-secret", "text/openvpn-conf", "text/redis-conf"])

def handle_part(data,ctype,filename,payload):
  # data: the cloudinit object
  # ctype: '__begin__', '__end__', or the specific mime-type of the part
  # filename: the filename for the part, or dynamically generated part if
  #           no filename is given attribute is present
  # payload: the content of the part (empty for begin or end)
  if ctype == "__begin__":
    print "my handler is beginning"
    return
  if ctype == "__end__":
    print "my handler is ending"
    return
  if ctype == "text/openvpn-secret":
    print "handling %s " % ctype
    import os
    out = "/etc/openvpn/secret/%s" % filename
    d = os.path.dirname(out)
    if not os.path.exists(d):
        os.makedirs(d)
    f = open(out, 'w')
    f.write(payload)
    f.close()
    os.chmod(out, 0600)
    return
  if ctype == "text/openvpn-conf":
    print "handling %s " % ctype
    import os
    out = "/etc/openvpn/%s" % filename
    d = os.path.dirname(out)
    if not os.path.exists(d):
        os.makedirs(d)
    f = open(out, 'w')
    f.write(payload)
    f.close()
    return
  if ctype == "text/redis-conf":
    print "handling %s " % ctype
    import os
    out = "/etc/redis.conf"
    d = os.path.dirname(out)
    if not os.path.exists(d):
        os.makedirs(d)
    f = open(out, 'w')
    f.write(payload)
    f.close()
    return
