# coding: utf-8

# ---------------------------------------------------------------------------------------

# mount partition read-only
# sudo mount -t "ntfs" -ro "uhelper=udisks2,nodev,nosuid,uid=1000,gid=1000" "/dev/sda1" "/home/thiago/Desktop/temp-data"

def get_pending_files
  # todo filter lines already processed (starts with OK)
  files = File.readlines("db/processing.txt").map{|f| f.chomp("\n")}
end

def generate_filenames_list
  conf.echo = false
  files = filenames
  conf.echo = true
  puts "#{files.size} files found."

  # start with 10k files
  files = files[0..1000].select{|f| File.exists?(f) }

  File.open("db/processing.txt", "w+") do |f|
    f.puts(files)
  end
  puts 'saved file list on processing.txt'
end

def filenames
  cvs_path = "/home/kevin/Desktop/temp-data"
  output = `ls -f -A #{cvs_path}`
  dirs = output.split("\n").drop(2) # skip . and ..

  files = dirs.map {|item|
    path = cvs_path + "/#{item}/curriculo.xml"
    path
  }
  files
end

# ---------------------------------------------------------------------------------------

#create indices before seeding...
puts 'creating indices...'
Rake::Task['db:mongoid:create_indexes'].invoke

#files = Dir.glob('cvs/amostra/*.xml')
files = get_pending_files

# save files adding dynamic fields
puts '------------------------------------------'
puts 'XMLS'
puts '------------------------------------------'

hashes = files.map{|file|
                    xml = File.read(file).encode('utf-8')
                    hash = Hash.from_xml(xml)
                    cv = CV.new(hash)
                    cv.save!

                    hash
                  }

#hashes.each do |hash|
#  cv = CV.new(hash)
#  cv.save!
#end

puts '------------------------------------------'
puts "#{CV.all.size} files added to mongo!"
puts '------------------------------------------'

# save researchers (semi-structured)
puts '------------------------------------------'
puts 'RESEARCHERS AND PUBLICATIONS'
puts '------------------------------------------'

hashes.each_with_index do |hash, index|
  model = Researcher.from_hash(hash)
  begin
    model.save!
    # TODO multiple publications...
    publications = Publication.from_hash(hash)
    model.publications.push(publications.first)
    model.save!
  rescue => ex
    puts 'error on: #{model.name}'
    puts ex.message
  end
end

# create researchers for coauthors
#TODO refactor
#TODO remove duplicates researchers from database

#names = Researcher.all.map{|r| [r.name, true]}.to_h
#names_in_citation = Researcher.all.map{|r| [r.name_in_citations, true]}.to_h

Researcher.all.map(&:publications).flatten.compact.
  map(&:coauthors).flatten.compact.
  uniq{|coauthor| coauthor[:name] }.
  each do |coauthor|
    begin
      puts coauthor[:name]
      Researcher.create!(name: coauthor[:name], name_in_citations: coauthor[:name_in_citations])
    rescue => ex
      puts ex.message
    end
  end


puts '------------------------------------------'
puts "#{Researcher.all.size} researchers added to mongo!"
puts "#{Researcher.all.map{|r| r.publications.size }.sum} publications added to mongo!"
puts '------------------------------------------'

# save test researchers example from paper
puts '------------------------------------------'
puts 'ADD TEST RESEARCHER Kristen Nygaard WITH TWO PUBLICATIONS IN THE SAME YEAR'
puts '------------------------------------------'

model = Researcher.create(name: "Test Author",
                       name_in_citations: "Test citations",
                       country: "Canada",
                       resume: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                       institution: "Carleton University")
model.save!

model.publications.create([
  { nature: "COMPLETO1", title: "Rosing Prize Paper Test1", year: 1999, country: "Noruega", language: "Inglês", medium: "IMPRESSO"},
  { nature: "COMPLETO1", title: "Turing Award Paper Test1", year: 2001, country: "Noruega", language: "Inglês", medium: "IMPRESSO"},
  { nature: "COMPLETO1", title: "IEEE John von Neumann Medal Paper Test1", year: 2001, country: "Noruega", language: "Inglês", medium: "IMPRESSO"}
])

model.save!

puts '------------------------------------------'
puts "#{Researcher.all.size} researchers added to mongo!"
puts "#{Researcher.all.map{|r| r.publications.size }.sum} publications added to mongo!"
puts '------------------------------------------'
