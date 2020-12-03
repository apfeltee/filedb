
# the root directory where find will start searching.
# must *NOT* end with a slash!
MKA_ROOTPATH = '/cygdrive/c'

# the kind of rootpath you want to replace with
MKA_NEWROOTPATH = 'c:'

# the output file location (note: MUST be absolute!)
MKA_OUTPUTFILE = File.join(Dir.pwd, 'allfiles.db')

MKA_FINDFMTSEPARATOR = ';;;'

MKA_FIELDSEPARATOR = "\t"

MKA_ROOTREGEX = /^\./

MKA_STAGEMAX = (1024 * 1)

# any paths you want to skip.
# note that these are NOT regular expressions or globs!
# paths may contain slashes, and start off at MKA_ROOTPATH.
# however, they must NOT start with a slash.
# example: adding "foobar" would match MKA_ROOTPATH/foobar,
# "blah/things" would match MKA_ROOTPATH/blah/things, and so on.
# paths added here are pruned, rather than skipped, since that
# makes find quite a lot faster.
MKA_BADPATHS = [
  "boot*",
  "Sandbox",
  "$Recycle.Bin",
  "$RECYCLE.BIN",
  "$SysReset",
  "Recovery",
  #"Cygwin",
  "MinGW",
  "Users/sebastian/Desktop/reddpics",
  "Users/sebastian/Desktop/shitware",
  "Users/sebastian/AppData/Local/Zeal",
  "Windows/WinSxS",
]


#########################################
##### edit below at YOUR OWN RISK! ######
#########################################

# temporary datatype for tablayout
TABITEM = Struct.new(:type, :is_file_stat, :file_stat_member)

# (only relevant with sqlite) the name of the table
MKA_TABLENAME = :items


# what items to to store in the database
# syntax: <fieldname> => TABITEM.new(<datatype>, <is it a member of File::Stat?>, <name of File::Stat member>)
#
# NOTE: this really only works because ruby
# keeps hash keys in order -- needs to replaced with an array
# at some point!
MKA_TABLAYOUT = {
  #:inode     => TABITEM.new(:Numeric, true, :ino)
  #:sizebytes => TABITEM.new(:Numeric, true, :size),
  #:blocks    => TABITEM.new(:Numeric, true, :blocks),
  :sizehuman => TABITEM.new(:String, false, nil),
  :filepath  => TABITEM.new(:String, false, nil),
}


