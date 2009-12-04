module IR
  # Index is like a index
  # - used by Searcher, Indexer and InferenceNetwork
  # - contains document list and term statistics
  # - can be initialized from file or 
  class Index
    attr_accessor :cid, :docs, :dh
    attr_accessor :lm, :df, :flm #collection statistics

    # @param [Array<IR::Document>] docs : documents 
    # @option o [Array] :fields accept the list of fields
    def initialize(docs = nil, o={})
      @cid = o[:cid]
      @docs = docs || []
      @dh = docs.map_hash{|d|[d.dno, d]}
      @docs.each{|d|d.col = self}
      
      @idf = {} # cache of IDF
      @lm = o[:lm]   || LanguageModel.create_by_merge(docs.map{|d|(d.lm)? d.lm.f : {}})
      @flm = {} ; @flm[:document] = @lm
      if o[:fields]
        o[:fields].each do |field|
          @flm[field] = LanguageModel.create_by_merge(docs.map{|d|d.flm[field].f})
        end
      end
      @df = LanguageModel.create_by_merge(docs.map{|d|d.lm.f.map{|k,v|[k,1]}}).f if o[:init_df]
      info "Collection #{@cid} loaded (#{docs.size} docs)"
    end
    
    # Search based on similarity
    # - Find target document
    # - Evaluate similarity query
    def find_similar(dno, o={})
      query = dh[dno]
      return nil unless query

      weights = Vector.elements(o[:weights] || [1]*Searcher::FEATURE_COUNT)
      result = []
      @docs.each do |d|
        next if d.dno == query.dno
        #puts "[find_similar] Scoring #{d.id}"
        #puts "#{d.feature_vector(query).inspect}*#{weights.inspect}"
        score = d.feature_vector(query).inner_product(weights)#w[:content] * d.cosim(query) + w[:time] * d.tsim(query)
        result << [d.dno, score] if !score.nan?
      end
      #debugger
      result.sort_by{|e|e[1]}.reverse[0..50]
    end
    
    # Log pairwise preference training data into file
    # @param[String] query : query_id|clicked_item_id|skipped_item_id|...
    def log_preference(dnos, o={})
      dnos = dnos.split("|").map{|e|e.to_i}
      #puts "[log_preference] dnos=#{dnos.inspect}"
      query = dh[dnos[0]]
      return nil unless query

      result = []
      $last_query_no += 1
      dnos[1..-1].each_with_index do |dno,i|
        next if i > 0 && $clf.read('c', dno, query.dno) > 0
        features = dh[dno].feature_vector(query).to_a.map_with_index{|e,j|[j+1,fp(e)].join(":")}
        pref = (i == 0)? 2 : 1
        result << [pref,"qid:#{$last_query_no}"].concat(features).concat(["# #{query.dno} -> #{dno}"])
      end
      if !o[:export_mode]
        $clf.increment('c', dnos[0], dnos[1])
        SysConfig.find_by_title("LAST_QUERY_NO").update_attributes(:content=>$last_query_no) 
      end
      $f_li.puts result.map{|e|e.join(" ")}.join("\n") if result.size > 1
      $f_li.flush
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
