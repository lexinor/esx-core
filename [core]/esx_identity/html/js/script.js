const dateofbirth = document.querySelector('#dateofbirth');
const datepicker = new Datepicker(dateofbirth, {
  format: "dd/mm/yyyy",
  language: "fr",
  maxDate: "01/01/2006",
  minDate: "01/01/1940",
  defaultViewDate: "01/01/2000",
  autohide: true,
  beforeShowDay: (date) => {
    return {
        classes: 'has-background-info',
    };
  },
});

window.addEventListener("message", (event) => {
    if (event.data.type === "enableui") {
        document.body.classList[event.data.enable ? "remove" : "add"]("none");
    }
});

document.querySelector("#register").addEventListener("submit", (event) => {
    event.preventDefault();

    // const dofVal = document.querySelector("#dateofbirth").value;
    const dofVal = datepicker.getDate();
    
    if (!dofVal) return;

    const dateCheck = new Date(dofVal);

    const year = new Intl.DateTimeFormat("en", { year: "numeric" }).format(dateCheck);
    const month = new Intl.DateTimeFormat("en", { month: "2-digit" }).format(dateCheck);
    const day = new Intl.DateTimeFormat("en", { day: "2-digit" }).format(dateCheck);

    const formattedDate = `${day}/${month}/${year}`;
    fetch("http://esx_identity/register", {
        method: "POST",
        body: JSON.stringify({
            firstname: document.querySelector("#firstname").value,
            lastname: document.querySelector("#lastname").value,
            dateofbirth: formattedDate,
            sex: document.querySelector("input[type='radio'][name='sex']:checked").value,
            height: document.querySelector("#height").value,
        }),
    });

    document.querySelector("#register").reset();
});

document.addEventListener("DOMContentLoaded", () => {
    fetch("http://esx_identity/ready", {
        method: "POST",
        body: JSON.stringify({}),
    });
});
