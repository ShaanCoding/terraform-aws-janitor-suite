console.log("Loading function");

module.exports.existingLogGroups = async (event, context) => {
  const retentionDays = parseInt(process.env.RETENTION_DAYS || 7);

  console.log(
    `Fetching existing log groups with retention days set to ${retentionDays}`
  );

  console.log("Event:", JSON.stringify(event, null, 2));
  console.log("Context:", JSON.stringify(context, null, 2));
};

module.exports.newLogGroups = async (event, context) => {
  const retentionDays = parseInt(process.env.RETENTION_DAYS || 7);

  console.log(
    `Fetching new log groups with retention days set to ${retentionDays}`
  );

  console.log("Event:", JSON.stringify(event, null, 2));
  console.log("Context:", JSON.stringify(context, null, 2));
};
