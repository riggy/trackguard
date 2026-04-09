class CreateVisitorsAndAddVisitorIdToPageViews < ActiveRecord::Migration[8.1]
  def up
    create_table :visitors do |t|
      t.string   :ip
      t.string   :user_agent
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at,  null: false
      t.datetime :flagged_at
      t.string   :flag_reason
      t.timestamps
    end
    add_index :visitors, :ip, unique: true

    add_reference :page_views, :visitor, null: true, foreign_key: true

    # Backfill: create one Visitor per unique IP and associate page_views
    PageView.where.not(ip: [ nil, "" ]).distinct.pluck(:ip).each do |ip|
      rows = PageView.where(ip: ip).order(:created_at)
      visitor = Visitor.create!(
        ip:            ip,
        user_agent:    rows.last.user_agent,
        first_seen_at: rows.first.created_at,
        last_seen_at:  rows.last.created_at
      )
      PageView.where(ip: ip).update_all(visitor_id: visitor.id)
    end

    remove_column :page_views, :ip, :string
  end

  def down
    add_column :page_views, :ip, :string

    # Restore ip from visitor association
    PageView.includes(:visitor).find_each do |pv|
      pv.update_column(:ip, pv.visitor&.ip)
    end

    remove_reference :page_views, :visitor, foreign_key: true
    drop_table :visitors
  end
end
