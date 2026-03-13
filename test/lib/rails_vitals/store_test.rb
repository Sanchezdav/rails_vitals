require "test_helper"

class RailsVitalsStoreTest < ActiveSupport::TestCase
  Record = Struct.new(:id)

  test "#push returns bounded queue state when size is exceeded" do
    store = RailsVitals::Store.new(2)

    store.push(Record.new("first"))
    store.push(Record.new("second"))
    store.push(Record.new("third"))

    records = store.all
    assert_equal 2, records.size
    assert_equal [ "second", "third" ], records.map(&:id)
  end

  test "#all returns defensive copy Array of stored records" do
    store = RailsVitals::Store.new(3)
    store.push(Record.new("one"))

    copy = store.all
    copy << Record.new("mutated")

    assert_equal [ "one" ], store.all.map(&:id)
  end

  test "#find returns matching record by id and nil when record is missing" do
    store = RailsVitals::Store.new(3)
    record = Record.new("req_123")
    store.push(record)

    assert_equal record, store.find("req_123")
    assert_nil store.find("req_missing")
  end

  test "#clear removes all records and #size returns Integer count" do
    store = RailsVitals::Store.new(3)
    store.push(Record.new("one"))
    store.push(Record.new("two"))

    assert_equal 2, store.size
    assert_equal 2, store.all.size

    store.clear

    assert_equal 0, store.size
    assert_equal [], store.all
  end

  test "#push returns size-bounded store under concurrent writes" do
    store = RailsVitals::Store.new(50)

    threads = 10.times.map do |thread_index|
      Thread.new do
        20.times do |item_index|
          store.push(Record.new("t#{thread_index}_#{item_index}"))
        end
      end
    end
    threads.each(&:join)

    assert_equal 50, store.size
    assert_equal 50, store.all.size
  end
end
