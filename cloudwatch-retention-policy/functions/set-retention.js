module.exports.existingLogGroups = async () => {
  const retentionDays = parseInt(process.env.RETENTION_DAYS, 7);

  console.log(
    `Fetching existing log groups with retention days set to ${retentionDays}`
  );
};

module.exports.newLogGroups = async () => {
  const retentionDays = parseInt(process.env.RETENTION_DAYS, 7);

  console.log(
    `Fetching new log groups with retention days set to ${retentionDays}`
  );
};
