# Generated migration to add city_admin field to Department

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('complaints', '0011_remove_cityadmin_location_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='department',
            name='city_admin',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, to='complaints.cityadmin'),
        ),
    ]