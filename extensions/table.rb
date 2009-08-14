# 2D Array working as a Table
# self : [[e1-1, e1-2, ...], [e2-1, e2-2, ...], ...]
# Header/Summary row marked with ("%" )
module Table
  # Format each row as table with min/max highlight
  # self : [e1-1, e1-2, ...]
  def to_tbl(o={})
    style = (o[:style])? "{#{o[:style]}}. " : ""
    a = case o[:mode]
        when :max
          max_e = max.to_f
          map{|e|(e==max_e)? "*#{e.to_s}*" : "#{e}(#{((e-max_e)/max_e*100).round_at(1)}%)"}
        when :min
          min_e = min.to_f
          map{|e|(e==min_e)? "#{e.to_s}" : "#{e}(#{((e-min_e)/min_e*100).round_at(1)}%)"}
        else
          self
        end
    "|"+style+a.join('|')+"|"
  end
  
  def add_col()
    
  end
  
  def add_summary_col(o={})
    
  end
  
  def transpose
    
  end
end