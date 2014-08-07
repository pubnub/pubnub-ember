#
# NOTHING USEFUL HERE - just a utility script to
# keep the distribution up to date!
#

puts 'generating coffee'
`coffee -o site site`

files = `find site -name "*.haml"`.split("\n")
files.each do |m|
  infile  = m
  outfile = m.gsub(/\.haml$/, ".html")
  cmd = "haml #{infile} > #{outfile}"
  puts cmd
  `#{cmd}`
end

files = `find site -name "*.asciidoc"`.split("\n")
files.each do |m|
  infile  = m
  cmd = "asciidoctor #{infile}"
  puts cmd
  `#{cmd}`
end

