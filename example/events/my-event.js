function OnUpdate(doc, meta) {
  // This example event copies all documents from the "example" bucket to the "default" bucket

  dst[meta.id] = doc;
}

function OnDelete(meta) {
}
