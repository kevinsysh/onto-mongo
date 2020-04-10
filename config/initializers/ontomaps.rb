OntoMap.mapping 'Pesquisador' do
  model Researcher
  maps from: 'nome', to: :name
  maps from: 'pais', to: :coutry
  maps from: 'nome_em_citacoes', to:  :name_in_citations
  maps from: ':instuition ', to:  :instuition 
  maps relation: ':published', to: :publications
end

OntoMap.mapping 'Publicacao' do
  model Publication
  maps from: 'nature', to: :nature
  maps from: 'title', to:  :title
  maps from: 'title_en', to:  :title_en
  maps from: 'year', to:  :year
  maps from: 'country', to:  :country
  maps from: 'language', to:  :language
  maps from: 'medium', to:  :medium
  maps from: 'doi', to:  :doi
end
