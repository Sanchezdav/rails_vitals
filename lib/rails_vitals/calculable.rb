module RailsVitals
  module Calculable
    def average(records, method)
      return 0.0 if records.empty?

      (records.sum(&method).to_f / records.size).round(1)
    end

    def percentage(count, total)
      return 0.0 if total.zero?

      (count.to_f / total * 100).round(1)
    end
  end
end
