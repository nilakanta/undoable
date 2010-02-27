module EqualSetsMatcher
  class EqualSets
    def initialize(expected)
      @expected = expected
    end

    def matches?(target)
      @target = target
      target_ary, expected_ary = @target.to_a, @expected.to_a        
      target_ary.all? { |o| expected_ary.include?(o) } && expected_ary.all? { |o| target_ary.include?(o) }
    end

    def failure_message
      "expected the set #{@target.inspect} to have equal elements as #{@expected.inspect}, but it doesn't"
    end

    def negative_failure_message
      "expected the set #{@target.inspect} not to have equal elements as #{@expected.inspect}, but it does"
    end
  end                                                   
  
  def equal_sets(expected)
    EqualSets.new(expected)
  end
  alias_method :equal_set, :equal_sets  
end