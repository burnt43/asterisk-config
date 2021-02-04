require './test/test_helper.rb'

class ParserTest < Minitest::Test
  def test_parse_handles_multiple_of_the_same_keys_correctly
    parser = AsteriskConfig::Parser.new('./test/assets/config_with_multiple_same_keys.txt')
    result = parser.parse
    category = result['cat1']

    assert_equal('foo', category.attr1)
    assert_equal(%w[bar piyo hige], category.attr2)
    assert_equal('qux', category.attr3)
  end

  def test_as_option
    parser = AsteriskConfig::Parser.new('./test/assets/data_type_type_casting.txt')
    result = parser.parse
    category = result['cat1']

    assert_equal('10', category.int_val)
    assert_equal(10, category.int_val(as: :int))

    assert_equal('i0,i1,i2', category.array_val)
    assert_equal(%w[i0 i1 i2], category.array_val(as: :array))

    assert_equal('25-48', category.range_val)
    assert_equal(25..48, category.range_val(as: :range))

    assert_equal(%w[100 200], category.multi_int_val)
    assert_equal([100, 200], category.multi_int_val(as: :int))

    assert_equal(%w[1-24 25-48], category.multi_range_val)
    assert_equal([1..24, 25..48], category.multi_range_val(as: :range))

    assert_equal(%w[1,2,3 4,5,6], category.multi_array_val)
    assert_equal(%w[1 2 3 4 5 6], category.multi_array_val(as: :array))
  end

  def test_ssh_option_string
    parser_01 = AsteriskConfig::Parser.new(
      './test/assets/this_file_does_not_exist.txt'
    )
    assert_equal('', parser_01.send(:ssh_option_string))

    parser_02 = AsteriskConfig::Parser.new(
      './test/assets/this_file_does_not_exist.txt',
      ssh_kex_algorithm: 'fake-algo'
    )
    assert_equal('-oKexAlgorithms=+fake-algo', parser_02.send(:ssh_option_string))

    parser_03 = AsteriskConfig::Parser.new(
      './test/assets/this_file_does_not_exist.txt',
      ssh_identity_file: '/home/user/.ssh/id_rsa',
      ssh_kex_algorithm: 'fake-algo'
    )
    assert_equal('-i /home/user/.ssh/id_rsa -oKexAlgorithms=+fake-algo', parser_03.send(:ssh_option_string))

    parser_04 = AsteriskConfig::Parser.new(
      './test/assets/this_file_does_not_exist.txt',
      ssh_identity_file: '/home/user/.ssh/id_rsa'
    )
    assert_equal('-i /home/user/.ssh/id_rsa', parser_04.send(:ssh_option_string))
  end

  def test_ssh_destination
    parser_01 = AsteriskConfig::Parser.new(
      './test/assets/this_file_does_not_exist.txt'
    )
    assert_equal('localhost', parser_01.send(:ssh_destination))

    parser_02 = AsteriskConfig::Parser.new(
      './test/assets/this_file_does_not_exist.txt',
      'remote-host'
    )
    assert_equal('remote-host', parser_02.send(:ssh_destination))

    parser_03 = AsteriskConfig::Parser.new(
      './test/assets/this_file_does_not_exist.txt',
      'remote-host',
      ssh_user: 'somedude'
    )
    assert_equal('somedude@remote-host', parser_03.send(:ssh_destination))
  end
end
