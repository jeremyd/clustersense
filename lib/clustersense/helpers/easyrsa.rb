WRITE_MIME="python2 ~/recent_projects/cloud-utils/bin/write-mime-multipart"
USER_DATA_SCRIPTS=File.expand_path(File.join(Clustersense::AGENTS_DIR, ".." ,"..", "user-data"))
USER_DATA_TMP="/tmp/user-data.txt"

class EasyRSA
  def initialize(easy_rsa_dir)
    @easy_rsa = easy_rsa_dir
  end

  def setvar(name, val)
    ENV[name.upcase] = val
  end

  # the required env variables to run easyrsa scripts
  def vars(name, ou)
    setvar "easy_rsa", @easy_rsa
    setvar "openssl", "openssl"
    setvar "pkcs11tool", "pkcs11-tool"
    setvar "grep", "grep"
    #setvar "key_config", `#{@easy_rsa}/whichopensslcnf #{@easy_rsa}` 
    setvar "key_config", "#{@easy_rsa}/openssl-1.0.0.cnf" 
    setvar "key_dir", "#{@easy_rsa}/keys"
    setvar "pkcs11_module_path", "dummy"
    setvar "pkcs11_pin", "dummy"
    setvar "key_size", "1024"
    setvar "ca_expire", "3650"
    setvar "key_expire", "3650"
    setvar "key_country", "US"
    setvar "key_province", "CA"
    setvar "key_city", "San Francisco"
    setvar "key_org", "Mission Distrikt"
    setvar "key_email", "na@myl33tbox.com"
    setvar "key_name", name
    setvar "key_ou", ou
    setvar "pkcs11_module_path", "changeme"
    setvar "pkcs11_pin", "1234"
  end

  def gen_client_key(name)
    vars(name, name)
    output = `#{@easy_rsa}/pkitool #{name}`
    if $?.success?
      output += "key generated successfully!"
    else
      output += "something went wrong generating the key.."
    end
    output
  end

  def list_keys
    Dir.glob("#{@easy_rsa}/keys/*.key")
  end
end

class OvpnClient
  #options: ca, cert, key, tls_auth
  def initialize(options)
    @easy_rsa = ENV['EASY_RSA']
    raise "FATAL: not passed the right options in OvpnClient.new, needs :ca, :cert, :key and :tls_auth and :serverip" unless
      options[:ca] && options[:cert] && options[:key] && options[:tls_auth] && options[:serverip]
    @ca = options[:ca]
    @cert = options[:cert]
    @key = options[:key]
    @tls_auth = options[:tls_auth]
    @serverip = options[:serverip]
  end

  def config(config_path = "/etc/openvpn/client.conf")
     # Write out config for openvpn client.conf
    openvpn_client_config = <<EOF
    client
    dev tun
    proto udp
    remote #{@serverip} 1194
    resolv-retry infinite
    nobind
    user nobody
    group nobody
    persist-key
    persist-tun
    ca #{@ca}
    cert #{@cert}
    key #{@key}
    tls-auth #{@tls_auth} 1
    comp-lzo
    verb 3
EOF
    puts `sudo mv #{config_path} #{config_path}.bak` if File.exists?(config_path)
    File.open(File.join(@easy_rsa, "openvpn_client.conf"), "w") { |f| f.write(openvpn_client_config) }
    puts `sudo cp #{File.join(@easy_rsa, "openvpn_client.conf")} #{config_path}`
  end

  def cycle
    puts "Cycling connection to homebase OpenVPN network"
    puts `sudo systemctl restart openvpn@client 2>&1`
    sleep 5
  end
end
