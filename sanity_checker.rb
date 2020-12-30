require 'asterisk-config'
require 'active_support'

parser = AsteriskConfig::Parser.new(
  '/etc/asterisk/ss7.conf',
  'cm-mg0',
  ssh_kex_algorithm: 'diffie-hellman-group1-sha1'
)
hash = parser.parse
puts hash['host-cm-mg2'].links(as: :array).to_s

parser2 = AsteriskConfig::Parser.new(
  '/etc/asterisk/ss7.conf',
  'nb-mg0'
)
hash2 = parser2.parse
puts hash2['host-nb-mg0'].links(as: :array).to_s
