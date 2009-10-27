module IR
  # Document in IR::Indexed Form
  class Document
    TEXT_SIZE = 4096
    attr_accessor :did, :text, :lm, :flm, :col

    # 
    def initialize(did, input, o = {})
      @did = did
      @fields = :document
      @col = o[:col]
      @flm = {}
      raise ArgumentError, "Field name :document not allowed!" if o[:fields] && o[:fields].include?(:document)
      case input.class.to_s
      when 'String'
        #@text = input[0..TEXT_SIZE]
        if o[:fields]
          @fields.concat( o[:fields])
          o[:fields].each{|f|
            ftext = input.find_tag(f)[0]
            warn "No content for #{did}:#{f}"if !ftext
            @flm[f] = LanguageModel.new(ftext)
            #debug "#{f}: #{@flm[f].size}"
          }
          @lm = LanguageModel.create_by_merge(@flm.map{|k,v|v.f})
        else
          @lm = LanguageModel.new(input)
        end
      when 'Hash' #{field1=>flm1,field2=>flm2,...}
        @flm = input
        #debugger
        @lm = LanguageModel.create_by_merge(input.map{|k,v|v.f})
        raise DataError unless @flm.map{|k,v|v.size}.sum == @lm.size
      end
      @flm[:document] = @lm
    end
    
    def tfidf_cosim(doc)
      @lm.tfidf(@col.df,@col.docs.size).cos_sim(doc.lm.tfidf(doc.col.df,doc.col.docs.size))
    end
    
    def to_trectext()
      template = ERB.new(IO.read("rubylib/ir/template/doc_trectext.xml.erb"))
      template.result(binding)
    end
    
    def to_yaml()
      result = [did]
      result << @flm.map_hash{|k,v|[k,v.f] if k != :document}
      result.to_yaml
    end
    
    def self.create_from_yaml(yaml_str)
      #debugger
      begin
        yaml_obj = YAML.load(yaml_str)
      rescue Exception => e
        error "[create_from_yaml] error in #{yaml_str[0..100]}", e
        return nil
      end      
      Document.new(yaml_obj[0], yaml_obj[1].map_hash{|k,v|[k,LanguageModel.new(v)]})
    end
  end
end