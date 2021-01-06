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
end
