require 'asterisk-config'
require 'active_support'

parser = AsteriskConfig::Parser.new(
  '/etc/asterisk/ss7.conf',
  'cm-mg0',
  ssh_kex_algorithm: 'diffie-hellman-group1-sha1'
)
hash = parser.parse
puts hash['host-cm-mg2'].links(as: :array).to_s
