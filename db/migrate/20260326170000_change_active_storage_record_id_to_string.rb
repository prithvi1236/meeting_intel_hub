class ChangeActiveStorageRecordIdToString < ActiveRecord::Migration[8.0]
  def up
    remove_index :active_storage_attachments, name: "index_active_storage_attachments_uniqueness"
    change_column :active_storage_attachments, :record_id, :string, null: false
    add_index :active_storage_attachments,
      [ :record_type, :record_id, :name, :blob_id ],
      unique: true,
      name: "index_active_storage_attachments_uniqueness"
  end

  def down
    remove_index :active_storage_attachments, name: "index_active_storage_attachments_uniqueness"
    change_column :active_storage_attachments, :record_id, :bigint, null: false
    add_index :active_storage_attachments,
      [ :record_type, :record_id, :name, :blob_id ],
      unique: true,
      name: "index_active_storage_attachments_uniqueness"
  end
end
