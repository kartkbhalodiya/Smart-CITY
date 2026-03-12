# Generated migration to remove location fields from CityAdmin

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('complaints', '0010_citizenprofile_aadhaar_number'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='cityadmin',
            name='latitude',
        ),
        migrations.RemoveField(
            model_name='cityadmin',
            name='longitude',
        ),
        migrations.RemoveField(
            model_name='cityadmin',
            name='coverage_radius',
        ),
    ]