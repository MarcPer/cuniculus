.PHONY: docs doc_server

docs: yard_lib_docs/.dirtimestamp

yard_lib_docs/.dirtimestamp: README.md lib/*.rb lib/cuniculus/*.rb
	@yard doc
	@touch yard_lib_docs/.dirtimestamp

doc_server:
	@yard server -r
