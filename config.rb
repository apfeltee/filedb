
# the root directory where find will start searching.
# must *NOT* end with a slash!
MKA_ROOTPATHS = {
  '/cygdrive/c' => 'c:',
  '/cygdrive/d' => 'd:',
}


# the output file location (note: MUST be absolute!)
MKA_OUTPUTFILE = File.join(Dir.pwd, 'allfiles.db')

# database method
# note: sqlite is MUCH slower
MKA_DBMETHOD = "text"

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
  # directories that contain a lot of files
  "Users/#{ENV["USER"]}/AppData/Local/Zeal",
  "Windows/WinSxS",
]


#########################################
##### edit below at YOUR OWN RISK! ######
#########################################

# separator of fields
# does not apply to sqlite
MKA_FIELDSEPARATOR = "\t"

# at which stage count to print a message
MKA_STAGEMAX = (1024 * 1)

# the regular expression to "fix" paths
# there's probably no reason for you to change this
MKA_ROOTREGEX = /^\./

# temporary datatype for tablayout
TABITEM = Struct.new(:name, :type, :is_file_stat, :file_stat_member)

# (only relevant with sqlite) the name of the table
MKA_TABLENAME = :items

# what items to to store in the database
# syntax: <fieldname> => TABITEM.new(<datatype>, <is it a member of File::Stat?>, <name of File::Stat member>)
#
# NOTE: this really only works because ruby
# keeps hash keys in order -- needs to replaced with an array
# at some point!
MKA_TABLAYOUT = [
  #TABITEM.new(:inode, :Numeric, true, :ino),
  #TABITEM.new(:sizebytes, :Numeric, true, :size),
  #TABITEM.new(:blocks, :Numeric, true, :blocks),
  TABITEM.new(:sizehuman, :String, false, nil),
  TABITEM.new(:filepath, :String, false, nil),
]


