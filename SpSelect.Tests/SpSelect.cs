using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using NUnit.Framework;

namespace SpSelect.Tests
{
    [TestFixture]
    public class SpSelect
    {
        [Test]
        public void ShouldReturnTableData()
        {

            var dates = new DateTime[]
                            {
                                new DateTime(2011, 3, 1),
                                new DateTime(2011, 3, 2)
                            };

            const int id = 1;
            const string name = "Cornichon";
            const double value = 100.25;

            using (var baseConnection = new SqlConnection(ConfigurationManager.AppSettings["ConnectionString"]))
            using (var baseCommand = new SqlCommand())
            {
                baseCommand.CommandText = @"CREATE TABLE #basicTempTable(id int primary key, name varchar(100), val numeric(10,3))";
                baseCommand.CommandType = CommandType.Text;
                baseCommand.Connection = baseConnection;
           
                baseConnection.Open();
                baseCommand.ExecuteNonQuery();

                baseCommand.CommandText = string.Format(@"insert into #basicTempTable values ({0}, '{1}', {2})", id, name, value);
                baseCommand.ExecuteNonQuery();

                using (var alternateConnection = new SqlConnection(ConfigurationManager.AppSettings["ConnectionString"]))
                using (var alternateCommand = new SqlCommand("exec sp_select 'tempdb..#basicTempTable'", alternateConnection))
                {
                    alternateConnection.Open();
                    using (var reader = alternateCommand.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            //// The parsing of the types should be eliminated when the feature is implemented
                            Assert.That(int.Parse(reader.GetString(0)), Is.EqualTo(id));
                            Assert.That(reader.GetString(1), Is.EqualTo(name));
                            Assert.That(decimal.Parse(reader.GetString(2)), Is.EqualTo(value));
                        }
                    }
                }
            }
        }

        [Test]
        public void ShouldFailWhenObjectDoesNotExist()
        {
            const string table = "tempdb..#tempTableDoesNotExist";
            using (var baseConnection = new SqlConnection(ConfigurationManager.AppSettings["ConnectionString"]))
            using (var baseCommand = new SqlCommand())
            {
                baseCommand.CommandText = string.Format("exec sp_select '{0}'", table);
                baseCommand.CommandType = CommandType.Text;
                baseCommand.Connection = baseConnection;

                baseConnection.Open();

                Assert.That(() => baseCommand.ExecuteReader(), 
                    Throws.Exception.TypeOf<SqlException>()
                        .With.Property("Message").ContainsSubstring(table)
                                                                );
            }
        }


    }
}
