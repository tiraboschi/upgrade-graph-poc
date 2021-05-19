.open olm_catalog_indexes/index.db.4.6.redhat-operators
.headers off
.output
SELECT
        "kubevirt-hyperconverged",
        "stable",
        e.name,
        0,
        e.version,
        e.skipRange,
        e.skips,
        r.name,
        "kubevirt-hyperconverged-operator.v2.6.2",
        "stable"
FROM
        operatorbundle e
LEFT JOIN
        operatorbundle r ON r.name = e.replaces;
	-- `exit 1` suppresses sqlite output at end of execution and just quits
.exit 1
