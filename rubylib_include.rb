require 'rubygems'
require 'ruby-debug'
require 'jcode'
$KCODE = "u"

#require 'test/unit'
require 'extensions/extensions.rb'
require 'extensions/exceptions.rb'
require 'globals/global.rb'
require 'ir/language_model.rb'
require 'ir/inference_network.rb'
require 'ir/stemmer.rb'
require 'ir/stopwords.rb'
require 'ir/index.rb'
require 'ir/document.rb'
require 'ir/concept_hash.rb'

#include Test::Unit::Assertions