module OsuRuby
  module Skin
    safe_glob(File.join(__dir__,barename(__FILE__))) do |fn| require fn end
  end
end
