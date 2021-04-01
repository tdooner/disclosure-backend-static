require 'set'

class TotalContributionsCalculator
  def initialize(candidates: [], ballot_measures: [], committees: [])
    @candidates_by_filer_id =
      candidates
        .find_all { |c| c.FPPC.present? }
        .index_by { |c| c.FPPC.to_s }
  end

  def fetch
    contributions_by_filer_id = {}

    summary_results = ActiveRecord::Base.connection.execute <<-SQL
      SELECT "Filer_ID", SUM("Amount_A") AS "Amount_A"
      FROM "Summary", candidates
      WHERE "Filer_ID" = "FPPC"::varchar
      AND "Form_Type" = 'F460'
      AND "Line_Item" = '5'
      AND ("Start_Date" IS NULL OR "From_Date" >= "Start_Date")
      AND ("End_Date" IS NULL OR "Thru_Date" <= "End_Date")
      GROUP BY "Filer_ID"
      ORDER BY "Filer_ID"
    SQL

    summary_results.each do |result|
      filer_id = result['Filer_ID'].to_s
      contributions_by_filer_id[filer_id] ||= 0
      contributions_by_filer_id[filer_id] += result['Amount_A'].to_f
    end

    # NOTE: We remove duplicate transactions on 497 that are also reported on
    # Schedule A during a preprocssing script. (See
    # `./../remove_duplicate_transactionts.sh`)
    late_results = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT "Filer_ID", SUM("Amount") AS "Total"
      FROM "497"
      WHERE "Filer_ID" IN ('#{@candidates_by_filer_id.keys.join "','"}')
      AND "Form_Type" = 'F497P1'
      GROUP BY "Filer_ID"
      ORDER BY "Filer_ID"
    SQL

    late_results.index_by { |row| row['Filer_ID'].to_s }.each do |filer_id, result|
      contributions_by_filer_id[filer_id] ||= 0
      contributions_by_filer_id[filer_id] += result['Total'].to_f
    end

    # For candidates where we specify a "Start Date", we include their initial
    # "Beginning Cash Balance" as a contribution so that our calculation of
    # their remaining balance matches up with their actual reported balance.
    starting_balances_by_filer_id.each do |filer_id, result|
      # Skip records with no Summary sheet for now, to prevent conflicting
      # `total_contributions` calculation with contribution_list_calculator.
      next unless contributions_by_filer_id.include?(filer_id)

      contributions_by_filer_id[filer_id] += result['Starting_Balance'].to_f
    end

    contributions_by_filer_id.each do |filer_id, total_contributions|
      candidate = @candidates_by_filer_id[filer_id]
      candidate.save_calculation(:total_contributions, total_contributions)
    end
  end

  def starting_balances_by_filer_id
    ActiveRecord::Base.connection.execute(<<-SQL).index_by { |r| r['Filer_ID'] }
      WITH first_filing_after_start_dates AS (
        -- Get the first report after the Start Date for each filer
        SELECT "Filer_ID", MIN("Thru_Date") as "Thru_Date"
        FROM "Summary", candidates
        WHERE "Filer_ID" = "FPPC"::varchar
        AND "Start_Date" IS NOT NULL
        AND "Thru_Date" >= "Start_Date"
        GROUP BY "Filer_ID"
      )
      SELECT "Summary"."Filer_ID", "Summary"."Thru_Date", "Amount_A" as "Starting_Balance"
      FROM "Summary"
      INNER JOIN first_filing_after_start_dates
        ON first_filing_after_start_dates."Filer_ID" = "Summary"."Filer_ID"
        AND first_filing_after_start_dates."Thru_Date" = "Summary"."Thru_Date"
      WHERE "Form_Type" = 'F460'
      AND "Line_Item" = '12';
    SQL
  end
end
