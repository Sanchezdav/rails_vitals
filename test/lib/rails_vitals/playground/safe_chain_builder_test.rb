require "test_helper"

class RailsVitalsSafeChainBuilderTest < ActiveSupport::TestCase
  Builder = RailsVitals::Playground::SafeChainBuilder

  setup do
    ActiveRecord::Base.connection.create_table(:chain_widgets, force: true) do |t|
      t.string :name
      t.integer :price
    end

    Object.const_set(:ChainWidget, Class.new(ActiveRecord::Base))

    ChainWidget.create!(name: "alpha", price: 10)
    ChainWidget.create!(name: "beta",  price: 20)
    ChainWidget.create!(name: "gamma", price: 30)
  end

  teardown do
    ActiveRecord::Base.connection.drop_table(:chain_widgets) rescue nil
    Object.send(:remove_const, :ChainWidget) if Object.const_defined?(:ChainWidget)
  end

  # ─── parse_chain ─────────────────────────────────────────────────

  test "parse_chain returns empty Array for blank string" do
    assert_equal [], Builder.send(:parse_chain, "")
    assert_equal [], Builder.send(:parse_chain, "   ")
  end

  test "parse_chain parses method with no arguments" do
    assert_equal [ [ "all", [] ] ], Builder.send(:parse_chain, "all")
    assert_equal [ [ "distinct", [] ] ], Builder.send(:parse_chain, "distinct")
  end

  test "parse_chain handles leading dot" do
    assert_equal [ [ "all", [] ] ], Builder.send(:parse_chain, ".all")
    assert_equal [ [ "all", [] ] ], Builder.send(:parse_chain, " .all")
  end

  test "parse_chain parses single symbol argument" do
    result = Builder.send(:parse_chain, "includes(:likes)")
    assert_equal "includes", result[0][0]
    assert_equal [ :likes ], result[0][1]
  end

  test "parse_chain parses multiple symbol arguments" do
    result = Builder.send(:parse_chain, "includes(:likes, :comments)")
    assert_equal [ :likes, :comments ], result[0][1]
  end

  test "parse_chain parses keyword hash arguments" do
    result = Builder.send(:parse_chain, "where(published: true)")
    assert_equal "where", result[0][0]
    assert_equal 1, result[0][1].size
    assert_equal({ published: true }, result[0][1].first)
  end

  test "parse_chain parses multi-key keyword hash" do
    result = Builder.send(:parse_chain, "where(published: true, archived: false)")
    assert_equal({ published: true, archived: false }, result[0][1].first)
  end

  test "parse_chain parses string argument" do
    result = Builder.send(:parse_chain, 'where("published = ?", true)')
    assert_equal "published = ?", result[0][1][0]
    assert_equal true, result[0][1][1]
  end

  test "parse_chain parses integer argument" do
    result = Builder.send(:parse_chain, "limit(10)")
    assert_equal [ 10 ], result[0][1]
  end

  test "parse_chain parses negative integer argument" do
    result = Builder.send(:parse_chain, "offset(-5)")
    assert_equal [ -5 ], result[0][1]
  end

  test "parse_chain parses keyword hash with symbol value" do
    result = Builder.send(:parse_chain, "order(created_at: :desc)")
    assert_equal({ created_at: :desc }, result[0][1].first)
  end

  test "parse_chain parses keyword hash with array value" do
    result = Builder.send(:parse_chain, "where(id: [1, 2, 3])")
    assert_equal({ id: [ 1, 2, 3 ] }, result[0][1].first)
  end

  test "parse_chain parses chain with multiple methods" do
    result = Builder.send(:parse_chain, "includes(:likes).where(published: true).limit(10)")
    assert_equal 3, result.size
    assert_equal [ "includes", "where", "limit" ], result.map(&:first)
    assert_equal [ :likes ], result[0][1]
    assert_equal({ published: true }, result[1][1].first)
    assert_equal [ 10 ], result[2][1]
  end

  test "parse_chain parses single-quoted string arg" do
    result = Builder.send(:parse_chain, "where(name: 'hello')")
    assert_equal({ name: "hello" }, result[0][1].first)
  end

  test "parse_chain parses single-quoted string with escaped quote" do
    result = Builder.send(:parse_chain, "where(name: 'he\\'s')")
    assert_equal({ name: "he's" }, result[0][1].first)
  end

  test "parse_chain parses unknown method name without raising" do
    result = Builder.send(:parse_chain, "foobar(1)")
    assert_equal [["foobar", [1]]], result
  end

  test "parse_chain parses disallowed class method connection" do
    result = Builder.send(:parse_chain, "connection.execute('SELECT 1')")
    assert_equal "connection", result[0][0]
    assert_equal "execute", result[1][0]
  end

  test "parse_chain parses but build rejects disallowed class method execute" do
    assert_equal [["execute", ["DROP TABLE users"]]], Builder.send(:parse_chain, "execute('DROP TABLE users')")
  end

  test "parse_chain parses but build rejects disallowed class method delete_all" do
    assert_equal [["delete_all", []]], Builder.send(:parse_chain, "delete_all")
  end

  test "parse_chain parses but build rejects disallowed class method destroy_all" do
    assert_equal [["destroy_all", []]], Builder.send(:parse_chain, "destroy_all")
  end

  test "parse_chain parses but build rejects disallowed class method eval" do
    result = Builder.send(:parse_chain, "eval('system(\"ls\")')")
    assert_equal "eval", result[0][0]
  end

  test "parse_chain raises ParseError for unterminated string" do
    assert_raises(Builder::ParseError) { Builder.send(:parse_chain, "where(name: 'hello)") }
  end

  test "parse_chain raises ParseError for unterminated array" do
    assert_raises(Builder::ParseError) { Builder.send(:parse_chain, "where(id: [1, 2)") }
  end

  # ─── build ────────────────────────────────────────────────────

  test "build returns model.all for blank chain" do
    # chain blank after model prefix strip gets model.all in Sandbox,
    # but here we test that build handles edge cases
    result = Builder.build(".all", ChainWidget)
    assert result.is_a?(ActiveRecord::Relation)
    assert_equal 3, result.size
  end

  test "build executes chained methods on relation" do
    result = Builder.build("where(price: 20)", ChainWidget)
    assert_equal 1, result.size
    assert_equal "beta", result.first.name
  end

  test "build handles string where clause" do
    result = Builder.build("where(\"name = ?\", 'alpha')", ChainWidget)
    assert_equal 1, result.size
    assert_equal "alpha", result.first.name
  end

  test "build handles limit" do
    result = Builder.build("limit(2)", ChainWidget)
    assert_equal 2, result.size
  end

  test "build handles select" do
    result = Builder.build("select(:name)", ChainWidget)
    assert_equal 3, result.size
    assert result.first.respond_to?(:name)
    assert_not result.first.respond_to?(:price)
  end

  test "build handles order with hash arg" do
    result = Builder.build("order(price: :desc)", ChainWidget)
    assert_equal "gamma", result.first.name
  end

  test "build raises ParseError for disallowed method" do
    assert_raises(Builder::ParseError) { Builder.build("connection.execute('DROP TABLE users')", ChainWidget) }
  end

  test "build raises ParseError for disallowed method delete_all" do
    assert_raises(Builder::ParseError) { Builder.build("delete_all", ChainWidget) }
  end

  test "build raises ParseError for disallowed method exec" do
    assert_raises(Builder::ParseError) { Builder.build("exec('rm -rf /')", ChainWidget) }
  end

  test "build raises ParseError with security-specific message" do
    error = assert_raises(Builder::ParseError) { Builder.build("connection.execute('DROP TABLE users')", ChainWidget) }
    assert_includes error.message, "not allowed for security reasons"
  end

  test "build raises ParseError for method not returning relation" do
    assert_raises(Builder::ParseError) { Builder.build("to_s", ChainWidget) }
  end

  test "build handles chained method calls" do
    result = Builder.build("where(price: [10, 20]).order(name: :asc)", ChainWidget)
    assert_equal 2, result.size
    assert_equal "alpha", result.first.name
    assert_equal "beta", result.second.name
  end

  # ─── Argument scanning ────────────────────────────────────────

  test "scans symbol with simple name" do
    s = StringScanner.new(":foo")
    assert_equal :foo, Builder.send(:scan_value, s)
  end

  test "scans symbol with double-quoted name" do
    s = StringScanner.new(':"foo bar"')
    assert_equal :"foo bar", Builder.send(:scan_value, s)
  end

  test "scans symbol with single-quoted name" do
    s = StringScanner.new(":'foo-bar'")
    assert_equal :"foo-bar", Builder.send(:scan_value, s)
  end

  test "scans integer" do
    s = StringScanner.new("42")
    assert_equal 42, Builder.send(:scan_value, s)
  end

  test "scans negative integer" do
    s = StringScanner.new("-7")
    assert_equal(-7, Builder.send(:scan_value, s))
  end

  test "scans float" do
    s = StringScanner.new("3.14")
    assert_equal 3.14, Builder.send(:scan_value, s)
  end

  test "scans boolean true" do
    s = StringScanner.new("true")
    assert_equal true, Builder.send(:scan_value, s)
  end

  test "scans boolean false" do
    s = StringScanner.new("false")
    assert_equal false, Builder.send(:scan_value, s)
  end

  test "scans nil" do
    s = StringScanner.new("nil")
    assert_nil Builder.send(:scan_value, s)
  end

  test "scans double-quoted string with escape sequences" do
    s = StringScanner.new('"hello\nworld"')
    assert_equal "hello\nworld", Builder.send(:scan_value, s)
  end

  test "scans double-quoted string with escaped quote" do
    s = StringScanner.new('"say \"hi\""')
    assert_equal 'say "hi"', Builder.send(:scan_value, s)
  end

  test "scans array of integers" do
    s = StringScanner.new("[1, 2, 3]")
    assert_equal [ 1, 2, 3 ], Builder.send(:scan_value, s)
  end

  test "scans hash literal with rocket syntax" do
    s = StringScanner.new('{"name" => "foo"}')
    assert_equal({ "name" => "foo" }, Builder.send(:scan_value, s))
  end

  test "scans hash literal with keyword syntax" do
    s = StringScanner.new("{name: 'foo', price: 10}")
    assert_equal({ name: "foo", price: 10 }, Builder.send(:scan_value, s))
  end

  test "scans hash literal with symbol keys rocket" do
    s = StringScanner.new("{:name => 'foo'}")
    assert_equal({ name: "foo" }, Builder.send(:scan_value, s))
  end
end
