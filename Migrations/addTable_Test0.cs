using System;
using FluentMigrator;

namespace Migrations
{
  [Migration(202110202101,"01 добавление таблицы Тест1")]
    public class  addTable_Test0: Migration
    {
        public override void Up()
        {
            Create.Table("Test1")
                .WithColumn("Id").AsInt64().PrimaryKey().Identity()
                .WithColumn("Text").AsString();
        }

        public override void Down()
        {
            Delete.Table("Log");
        }
    }
}