module OsuRuby
  module Constants
    # Mod name and values
    MODS = {
      NF:          0x1, # No Fail
      EM:          0x2, # It stands for "EASY MODO" for a reason.
      NV:          0x4, # No Video
      TD:          0x4, # Touch Device
      HD:          0x8, # Hidden
      HR:         0x10, # Hard Rock
      SD:         0x20, # Sudden Death
      DT:         0x40, # Double Time
      RL:         0x80, # Relax
      HT:        0x100, # Half Time
      NC:        0x200, # Nightcore
      FL:        0x400, # Flashlight
      Auto:      0x800, # Auto
      SO:       0x1000, # Spun Out
      ATP:      0x2000, # Auto Pilot
      PF:       0x4000, # Perfect
      "4K":     0x8000,
      "5K":    0x10000,
      "6K":    0x20000,
      "7K":    0x40000,
      "8K":    0x80000,
      SUD:    0x100000, # Sudden
      FI:     0x100000, # Fade In
      RD:     0x200000, # Random
      RAN:    0x200000,
      CIN:    0x400000, # Cinema
      MV:     0x400000,
      TP:     0x800000, # Target Practice
      "9K":  0x1000000,
      DP:    0x2000000, # Double Play
      COOP:  0x2000000,
      "1K":  0x4000000,
      "3K":  0x8000000,
      "2K": 0x10000000,
      ALT:  0x20000000, # Alternative Scoring (commonly called as V2)
      MIR:  0x40000000, # Mirror
    }.tap do |h|
      # Complement all nK mods
      h.keys.select do |k| k.match?(/^\d{1,2}K$/) end.tap do |kMods|
        kVals = kMods.map do |k| h[k] end
        h[:nK] = kVals.first(5).inject(0,:|)
        h[:AllK] = kVals.inject(0,:|)
      end
    end.freeze
    
    # List of osu! supported filetypes
    FILETYPE = {
      Beatmap: %w(.osu),
      Archive: %w(.zip .osz. .rar .osk),
      ArchiveSkin: %w(.osk),
      ArchivePack: %w(.rar),
      ArchivePackage: %w(.osz),
      EncrpytedPackage: %w(.osz2),
      EncryptedMobile: %w(.osc),
      Database: %w(.db),
      MediaAudio: %w(.ogg .mp3 .wav),
      MediaAudioMusic: %w(.ogg .mp3),
      MediaAudioSample: %w(.wav),
      MediaVideo: %w(.avi .flv .mpg .wmv .m4v .mp4),
      MediaImage: %w(.jpg .jpeg .png),
      Replay: %w(.osr),
      ReplayGhost: %w(.osg),
      MapStory: %w(.osb),
    }.freeze
  end
end
