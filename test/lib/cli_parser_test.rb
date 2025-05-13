# Import required testing framework
require 'minitest/autorun'
# Import the CLIParser class we're testing
require_relative '../../lib/cli_parser'

# Test class for CLIParser functionality
class CLIParserTest < Minitest::Test
  # Test parsing with valid query parameter
  def test_parse_with_valid_query
    # Test basic query parameter
    options = CLIParser.parse(['-q', 'test query'])
    assert_equal 'test query', options[:query]
    refute options[:tor]
    assert_nil options[:output]
  end

  # Test parsing with all available options
  def test_parse_with_all_options
    # Test all parameters together
    options = CLIParser.parse(['-q', 'test', '-t', '-o', 'output.txt'])
    assert_equal 'test', options[:query]
    assert options[:tor]
    assert_equal 'output.txt', options[:output]
  end

  # Test parsing with no parameters
  def test_parse_with_no_query
    # Should exit when no parameters provided
    assert_raises(SystemExit) { CLIParser.parse([]) }
  end

  # Test help flag
  def test_parse_with_help_flag
    # Should exit after displaying help
    assert_raises(SystemExit) { CLIParser.parse(['--help']) }
  end

  # Test invalid option handling
  def test_parse_with_invalid_option
    # Should raise error for unknown options
    assert_raises(OptionParser::InvalidOption) { CLIParser.parse(['--invalid']) }
  end

  # Test query parameter validation
  def test_parse_with_empty_query
    # Test empty string query
    output = capture_io do
      assert_raises(SystemExit) { CLIParser.parse(['-q', '']) }
    end
    assert_match(/Please provide a search query/, output.join)

    # Test nil query
    output = capture_io do
      assert_raises(SystemExit) { CLIParser.parse(['-q', nil]) }
    end
    assert_match(/Please provide a search query/, output.join)
  end
end