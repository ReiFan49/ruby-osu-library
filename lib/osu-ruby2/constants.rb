module OsuRuby
  module Constants
    MODS = {
      NF:          0x1,
      EM:          0x2, # It stands for "EASY MODO" for a reason.
      NV:          0x4,
      TD:          0x4,
      HD:          0x8,
      HR:         0x10,
      SD:         0x20,
      DT:         0x40,
      RL:         0x80, # RX IS DUMB AF. SHUT UP.
      HT:        0x100,
      NC:        0x200,
      FL:        0x400,
      Auto:      0x800,
      SO:       0x1000,
      ATP:      0x2000,
      PF:       0x4000,
      "4K":     0x8000,
      "5K":    0x10000,
      "6K":    0x20000,
      "7K":    0x40000,
      "8K":    0x80000,
      SUD:    0x100000,
      FI:     0x100000,
      RD:     0x200000,
      RAN:    0x200000,
      CIN:    0x400000,
      MV:     0x400000,
      TP:     0x800000,
      "9K":  0x1000000,
      DP:    0x2000000,
      COOP:  0x2000000,
      "1K":  0x4000000,
      "3K":  0x8000000,
      "2K": 0x10000000,
    }.tap do |h|
      h.keys.select do |k| k.match?(/^\d{1,2}K$/) end.tap do |kMods|
        kVals = kMods.map do |k| h[k] end
        h[:nK] = kVals.first(5).inject(0,:|)
        h[:AllK] = kVals.inject(0,:|)
      end
    end.freeze
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
