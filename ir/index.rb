module IR
  # Index is like a index
  # - used by Searcher, Indexer and InferenceNetwork
  # - contains document list and term statistics
  # - can be initialized from file or 
  class Index
    attr_accessor :cid, :docs, :lm, :df, :flm

    # @param [Array<IR::Document>] docs : documents 
    # @option o [Array] :fields accept the list of fields
    def initialize(docs = nil, o={})
      @cid = o[:cid]
      @docs = docs || []
      @docs.each{|d|d.col = self}
      @idf = {} # cache of IDF
      @lm = o[:lm]   || LanguageModel.create_by_merge(docs.map{|d|d.lm.f})
      @flm = {} ; @flm[:document] = @lm
      if o[:fields]
        o[:fields].each do |field|
          @flm[field] = LanguageModel.create_by_merge(docs.map{|d|d.flm[field].f})
        end
      end
      @df = LanguageModel.create_by_merge(docs.map{|d|d.lm.f.map{|k,v|[k,1]}}).f if o[:init_df]
      info "Documents : #{docs.size}"
    end

    # Get collection score
    # @param [String] query
    def col_score(query, type, o = {})
      parsed_query = InferenceNetwork.parse_query(query)
      debug "[col_score] parsed_query = #{parsed_query}"
      begin
        result = case type
        when :cql
          parsed_query.map{|e|@lm.f[e].to_f / @lm.size}.multiply
        end
      rescue Exception => e
        warn("[Index#col_score] result = 0 (exception)")      
      end
      #debug("[Index#col_score] query = #{parsed_query.join(' ')} / result = #{result}")
      result
    end

    # Used by Indexer
    def to_yaml()
      result = [@cid,@lm.f]
      result << @docs.map{|d|d.to_yaml}
      result.to_yaml
    end

    def self.create_from_yaml(yaml_str)
      yaml_obj = YAML.load(yaml_str)
      docs = yaml_obj[2].map{|e|Document.create_from_yaml(e)}
      lm = LanguageModel.new(yaml_obj[1])
      result = Index.new(docs, :lm=>lm, :cid=>yaml_obj[0])
      puts "[create_from_yaml] Index initialized (#{result.lm.size} / #{result.docs.map{|d|d.lm.size}.sum})"
      #debugger
    end

    def add_document(doc)
      @docs << doc
      @lm.update(doc.lm.f)
    end
  end  
end
