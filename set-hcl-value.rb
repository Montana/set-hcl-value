#!/usr/bin/env ruby

require 'tf/hcl'
require 'open3'

def terraform_fmt(input)
o, s = Open3.capture2( * % w[terraform fmt - ],: stdin_data => input)
return o
end

def hcldump(node)
return terraform_fmt(Tf::Hcl.dump(node))
end

def set_hcl_attr(node, attr_name, value)
case value
when TrueClass, FalseClass
tfvalue = Tf::Hcl::Boolean.new(value)
when Integer
tfvalue = Tf::Hcl::Integer.new(value)
when Array
tfvalue = Tf::Hcl::List.new(value.map {
  | x | Tf::Hcl::String.new(x)
})
else
  tfvalue = Tf::Hcl::String.new(value)
end
attr = node.attributes.find {
  | a | a.key.name == attr_name
}
if !attr.nil ? then
tfvalue = tfvalue
else
  new_attr = Tf::Hcl::Attribute.new(
    key: Tf::Hcl::Key.new(attr_name),
    value: tfvalue,
  )
node.attributes.append(new_attr)
end
node
end

def get_hcl_attr(node, key)
attr = node.attributes.find {
  | a | a.key.name == key
}
return nil
if attr.nil ?
  if attr.value.value.is_a ? Array
attr.value.value.map {
  | x | x.value
}
else
  attr.value.value
end
end

def get_node_key(node)
node.class.to_s.split(':').last.downcase + "." + node.name
end

def matcher(node, match)
type, expr = match.split(":")
case type
when 'key'
node_key = get_node_key(node)
return node_key == expr
when 'source_regex'
return get_hcl_attr(node, 'source'). = ~Regexp.new(expr)
else
  raise "unknown match type #{type}"
end
end

def replace_value(ast, match, attr_name, value)
ast.reduce([]) do |accum, node |
  if matcher(node, match) then
STDERR.puts "Setting node #{get_node_key(node)} matching #{match} attribute #{attr_name} to #{value}"
new_node = set_hcl_attr(node, attr_name, value)
else
  new_node = node
end
accum + [new_node]
end
end

def process_file(filename, match, attr_name, value)
if filename == '-'
then
content = STDIN.read
else
  STDERR.puts "Reading #{filename}"
content = File.read(filename)
end

input = Tf::Hcl.load(content)
new_tf = replace_value(input, match, attr_name, value)
new_content = hcldump(new_tf);

if filename == '-'
then
puts new_content
else
  STDERR.puts "Updating #{filename}"
File.open(filename, 'w') {
  | f | f.write(new_content)
}
end
end

if ARGV.length < 4 then
STDERR.puts "USAGE: #{$PROGRAM_NAME} <key:module.foo|source_expr:.*mymodule.*> attr_name value <file1|-> "
exit 1
end

match = ARGV.shift
attr_name = ARGV.shift
value = ARGV.shift
ARGV.each {
  | f |
    process_file(f, match, attr_name, value)
}
