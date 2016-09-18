require 'set'

class TotalContributionsCalculator
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @candidates_by_filer_id =
      candidates.where('"FPPC" IS NOT NULL').index_by { |c| c.FPPC }
  end

  def fetch
    @results = ActiveRecord::Base.connection.execute <<-SQL
      SELECT DISTINCT ON ("Filer_ID", "Amount_A")
        "Filer_ID", "Amount_A"
      FROM "efile_COAK_2016_Summary"
      WHERE "Filer_ID" IN ('#{@candidates_by_filer_id.keys.join "', '"}')
      AND "Form_Type" = 'F460'
      AND "Line_Item" = '5'
      GROUP BY "Filer_ID", "Amount_A", "Report_Num"
      ORDER BY "Filer_ID", "Amount_A", "Report_Num" DESC
    SQL

    @results.each do |result|
      candidate = @candidates_by_filer_id[result['Filer_ID'].to_i]
      candidate.save_calculation(:total_contributions, result['Amount_A'])
    end
  end
end

