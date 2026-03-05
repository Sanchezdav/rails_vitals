module RailsVitals
  class Store
    def initialize(size)
      @size    = size
      @records = []
      @mutex   = Mutex.new
    end

    def push(record)
      @mutex.synchronize do
        @records.push(record)
        @records.shift if @records.size > @size
      end
    end

    def all
      @mutex.synchronize { @records.dup }
    end

    def find(id)
      @mutex.synchronize do
        @records.find { |r| r[:id] == id }
      end
    end

    def clear
      @mutex.synchronize { @records.clear }
    end

    def size
      @mutex.synchronize { @records.size }
    end
  end
end
