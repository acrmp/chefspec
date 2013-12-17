nodesearch = search(:node, '*:*')
nodes = nodesearch.map(&:to_s).sort.join(', ')

log 'nodes' do
  message nodes
end

log 'nodenames' do
  message nodesearch.map{|n| '"' + n[:nodename].to_s + '"'}.sort.join(', ') #each { |n| n[:fqdn].to_s }
end