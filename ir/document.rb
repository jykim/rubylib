module IR
  # Document in IR::Indexed Form
  class Document
    TEXT_SIZE = 4096
    attr_accessor :dno, :did, :col
    attr_accessor :text, :lm, :flm, :fts
    # 
    def initialize(dno, did, input, o = {})
      @dno, @did = dno, did
      @fields = :document
      @col = o[:col]
      @fts = o[:features]
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
    
    def tsim(doc)
      value_sec = @fts[:basetime] - doc.fts[:basetime]
      value_n = 1 / Math.log((value_sec / 3600).abs+1)
      (value_n > 1)? 1 : value_n
    end
    
    def normalize(value)
      Math.log(value+1)
    end
    
    def feature_vector(doc)
      #debugger
      result = [tfidf_cosim(doc), tsim(doc)]
      result.concat CLTYPES.map{|t| normalize($clf.read(t, @dno, doc.dno).to_i) || 0 } if @col.cid == 'concepts'
      Vector.elements(result)
    end
    
    def to_trectext()
      template = ERB.new(IO.read("rubylib/ir/template/doc_trectext.xml.erb"))
      template.result(binding)
    end
    
    def to_yaml()
      result = [dno, did]
      result << @flm.map_hash{|k,v|[k,v.f] if k != :document}
      begin
        result.to_yaml        
      rescue Exception => e
        error "[Document::to_yaml] Unhandled Exceptions ", e
        nil
      end
    end
    
    def self.create_from_yaml(yaml_str, o = {})
      #debugger
      begin
        yaml_obj = YAML.load(yaml_str)
      rescue Exception => e
        error "[create_from_yaml] error", e
        return nil
      end
      index_content = yaml_obj[2].map_hash{|k,v|[k,LanguageModel.new(v)]} if yaml_obj[2] && yaml_obj[2].class == Hash
      Document.new(yaml_obj[0], yaml_obj[1], index_content, o)
    end
  end
end