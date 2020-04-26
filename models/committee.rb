class Committee < ActiveRecord::Base
  include HasCalculations

  def self.from_candidate(candidate)
    new(
      Filer_ID: candidate.FPPC,
      Filer_NamL: candidate.Committee_Name,
      candidate_controlled_id: '',
      data_warning: candidate.data_warning,
    )
  end

  def metadata
    {
      'filer_id' => self[:Filer_ID].to_s,
      'name' => self[:Filer_NamL],
      'candidate_controlled_id' => candidate_controlled_id.to_s,
      'data_warning' => data_warning,
      'opposing_candidate' => opposing_candidate,
      'title' => self[:Filer_NamL],
    }
  end

  def data
    {
      total_contributions: calculation(:total_contributions),
      contributions: calculation(:contribution_list) || [],
    }
  end
end
